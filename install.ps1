param(
  [string]$ManifestBaseUrl = "https://release.mediause.dev/cli",
  [string]$LatestUrl,
  [string]$InstallDir = "$env:USERPROFILE\.mediause\bin",
  [string]$BinaryName = "mediause",
  [switch]$Force
)

$ErrorActionPreference = "Stop"

function Get-PlatformKey {
  $isWindowsPlatform = [System.Runtime.InteropServices.RuntimeInformation]::IsOSPlatform(
    [System.Runtime.InteropServices.OSPlatform]::Windows
  )

  if (-not $isWindowsPlatform) {
    throw "This installer only supports Windows."
  }

  $archRaw = [string][System.Runtime.InteropServices.RuntimeInformation]::OSArchitecture
  if ([string]::IsNullOrWhiteSpace($archRaw)) {
    $archRaw = [string]$env:PROCESSOR_ARCHITECTURE
  }

  if ([string]::IsNullOrWhiteSpace($archRaw)) {
    throw "Unable to determine Windows architecture."
  }

  $arch = $archRaw.Trim().ToLowerInvariant()
  switch ($arch) {
    "arm64" { return "windows-arm64" }
    default { return "windows-x64" }
  }
}

function Resolve-Version {
  param([object]$LatestPayload)

  $version = $LatestPayload.version
  if (-not $version) { $version = $LatestPayload.latest }
  if (-not $version) { $version = $LatestPayload.tag_name }

  if (-not $version) {
    throw "latest.json missing version/latest/tag_name"
  }

  return ([string]$version).Trim().TrimStart("v")
}

function Normalize-Version {
  param([string]$Value)

  if ([string]::IsNullOrWhiteSpace($Value)) {
    return ""
  }

  return $Value.Trim().TrimStart("v")
}

function Parse-SemVer {
  param([string]$Value)

  $normalized = Normalize-Version -Value $Value
  $match = [regex]::Match($normalized, '^(?<core>\d+(?:\.\d+){0,2})(?:-(?<pre>[0-9A-Za-z\.-]+))?(?:\+(?<build>[0-9A-Za-z\.-]+))?$')
  if (-not $match.Success) {
    return $null
  }

  $coreParts = @($match.Groups['core'].Value.Split('.'))
  while ($coreParts.Count -lt 3) {
    $coreParts += '0'
  }

  return [PSCustomObject]@{
    Major = [int]$coreParts[0]
    Minor = [int]$coreParts[1]
    Patch = [int]$coreParts[2]
    PreRelease = $match.Groups['pre'].Value
  }
}

function Compare-SemVerIdentifiers {
  param(
    [string]$Left,
    [string]$Right
  )

  $leftParts = @($Left.Split('.'))
  $rightParts = @($Right.Split('.'))
  $max = [Math]::Max($leftParts.Count, $rightParts.Count)

  for ($i = 0; $i -lt $max; $i++) {
    $l = if ($i -lt $leftParts.Count) { $leftParts[$i] } else { $null }
    $r = if ($i -lt $rightParts.Count) { $rightParts[$i] } else { $null }

    if ($null -eq $l -and $null -eq $r) { return 0 }
    if ($null -eq $l) { return -1 }
    if ($null -eq $r) { return 1 }

    $lIsNum = $l -match '^\d+$'
    $rIsNum = $r -match '^\d+$'

    if ($lIsNum -and $rIsNum) {
      $ln = [int]$l
      $rn = [int]$r
      if ($ln -lt $rn) { return -1 }
      if ($ln -gt $rn) { return 1 }
      continue
    }

    if ($lIsNum -and -not $rIsNum) { return -1 }
    if (-not $lIsNum -and $rIsNum) { return 1 }

    $cmp = [string]::CompareOrdinal($l, $r)
    if ($cmp -lt 0) { return -1 }
    if ($cmp -gt 0) { return 1 }
  }

  return 0
}

function Compare-NormalizedVersions {
  param(
    [string]$Installed,
    [string]$Latest
  )

  $installedSemVer = Parse-SemVer -Value $Installed
  $latestSemVer = Parse-SemVer -Value $Latest

  if (-not $installedSemVer -or -not $latestSemVer) {
    return [string]::CompareOrdinal((Normalize-Version -Value $Installed), (Normalize-Version -Value $Latest))
  }

  if ($installedSemVer.Major -ne $latestSemVer.Major) {
    return [Math]::Sign($installedSemVer.Major - $latestSemVer.Major)
  }
  if ($installedSemVer.Minor -ne $latestSemVer.Minor) {
    return [Math]::Sign($installedSemVer.Minor - $latestSemVer.Minor)
  }
  if ($installedSemVer.Patch -ne $latestSemVer.Patch) {
    return [Math]::Sign($installedSemVer.Patch - $latestSemVer.Patch)
  }

  $installedPre = $installedSemVer.PreRelease
  $latestPre = $latestSemVer.PreRelease

  if ([string]::IsNullOrWhiteSpace($installedPre) -and [string]::IsNullOrWhiteSpace($latestPre)) {
    return 0
  }
  if ([string]::IsNullOrWhiteSpace($installedPre)) {
    return 1
  }
  if ([string]::IsNullOrWhiteSpace($latestPre)) {
    return -1
  }

  return Compare-SemVerIdentifiers -Left $installedPre -Right $latestPre
}

function Get-InstalledBinaryVersion {
  param([string]$BinaryPath)

  if (-not (Test-Path $BinaryPath)) {
    return $null
  }

  try {
    $jsonOutput = & $BinaryPath version --json 2>$null
    if ($LASTEXITCODE -eq 0 -and $jsonOutput) {
      $jsonText = ($jsonOutput | Out-String).Trim()
      try {
        $json = $jsonText | ConvertFrom-Json -ErrorAction Stop
        if ($json.version) {
          return Normalize-Version -Value ([string]$json.version)
        }
      } catch {
      }
    }
  } catch {
  }

  try {
    $plainOutput = & $BinaryPath --version 2>$null
    if ($LASTEXITCODE -eq 0 -and $plainOutput) {
      $text = ($plainOutput | Out-String).Trim()
      if ($text -match "([0-9]+\.[0-9]+\.[0-9]+(?:[-+][0-9A-Za-z\.-]+)?)") {
        return Normalize-Version -Value $matches[1]
      }

      return Normalize-Version -Value $text
    }
  } catch {
  }

  return $null
}

function Resolve-Assets {
  param(
    [object]$LatestPayload,
    [string]$Version,
    [string]$ManifestBaseUrl
  )

  if ($LatestPayload.assets) {
    return $LatestPayload.assets
  }

  $manifestUrl = "{0}/{1}.json" -f $ManifestBaseUrl.TrimEnd("/"), $Version
  Write-Host "latest.json has no assets, loading manifest: $manifestUrl"
  $manifest = Invoke-RestMethod -Uri $manifestUrl

  if (-not $manifest.assets) {
    throw "Manifest ${manifestUrl} missing assets"
  }

  return $manifest.assets
}

function Resolve-AssetForPlatform {
  param(
    [object]$Assets,
    [string]$PlatformKey
  )

  $asset = $null

  if ($Assets.PSObject.Properties.Name -contains $PlatformKey) {
    $asset = $Assets.$PlatformKey
  }

  if (-not $asset -and $PlatformKey -eq "windows-x64" -and $Assets.windows -and $Assets.windows.x64) {
    $asset = $Assets.windows.x64
  }

  if (-not $asset -and $PlatformKey -eq "windows-arm64" -and $Assets.windows -and $Assets.windows.arm64) {
    $asset = $Assets.windows.arm64
  }

  if (-not $asset) {
    $known = ($Assets.PSObject.Properties.Name -join ", ")
    throw "No artifact found for platform '${PlatformKey}'. Known keys: ${known}"
  }

  if (-not $asset.url) {
    throw "Artifact for '${PlatformKey}' has no url field"
  }

  return $asset
}

function Get-PathSegmentsLower {
  param([string]$PathValue)

  if ([string]::IsNullOrWhiteSpace($PathValue)) {
    return @()
  }

  return ($PathValue -split ";" |
    ForEach-Object { $_.Trim() } |
    Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
    ForEach-Object { $_.TrimEnd("\\").ToLowerInvariant() })
}

function Download-FileWithCacheBust {
  param(
    [string]$DownloadUrl,
    [string]$OutputPath,
    [string]$ExpectedSha256
  )

  $headers = @{
    "Cache-Control" = "no-cache"
    "Pragma" = "no-cache"
  }

  for ($attempt = 1; $attempt -le 2; $attempt++) {
    $requestUrl = $DownloadUrl
    if ($attempt -gt 1) {
      $separator = "?"
      if ($requestUrl.Contains("?")) {
        $separator = "&"
      }
      $requestUrl = "{0}{1}cb={2}" -f $requestUrl, $separator, ([Guid]::NewGuid().ToString("N"))
      Write-Host "Retrying download with cache-busting URL: $requestUrl"
    }

    Invoke-WebRequest -UseBasicParsing -Headers $headers -Uri $requestUrl -OutFile $OutputPath

    if ([string]::IsNullOrWhiteSpace($ExpectedSha256)) {
      return
    }

    $actualHash = (Get-FileHash -Path $OutputPath -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($actualHash -eq $ExpectedSha256) {
      return
    }

    if ($attempt -eq 2) {
      throw "SHA256 mismatch. expected=$ExpectedSha256 actual=$actualHash"
    }

    Write-Host "Checksum mismatch on downloaded file, retrying once to bypass CDN cache."
  }
}

try {
  $resolvedLatestUrl = if ([string]::IsNullOrWhiteSpace($LatestUrl)) {
    "{0}/latest.json" -f $ManifestBaseUrl.TrimEnd("/")
  } else {
    $LatestUrl
  }

  $platformKey = Get-PlatformKey
  Write-Host "Platform: $platformKey"
  Write-Host "Fetching latest release metadata: $resolvedLatestUrl"

  $latestPayload = Invoke-RestMethod -Uri $resolvedLatestUrl
  $version = Resolve-Version -LatestPayload $latestPayload
  $assets = Resolve-Assets -LatestPayload $latestPayload -Version $version -ManifestBaseUrl $ManifestBaseUrl
  $asset = Resolve-AssetForPlatform -Assets $assets -PlatformKey $platformKey

  $downloadUrl = [string]$asset.url
  $sha256 = if ($asset.sha256) { ([string]$asset.sha256).ToLowerInvariant() } else { "" }

  New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null

  $targetFile = Join-Path $InstallDir ("{0}.exe" -f $BinaryName)
  $shouldDownload = $true
  if ((Test-Path $targetFile) -and -not $Force) {
    $installedVersion = Get-InstalledBinaryVersion -BinaryPath $targetFile

    if ($installedVersion -and $installedVersion -eq $version) {
      $shouldDownload = $false
      Write-Host "Binary already exists: $targetFile"
      Write-Host "Local version matches latest ($version), skip download."
    } elseif ($installedVersion) {
      $cmp = Compare-NormalizedVersions -Installed $installedVersion -Latest $version
      Write-Host "Binary already exists: $targetFile"

      if ($cmp -lt 0) {
        Write-Host "Local version $installedVersion is lower than latest $version, upgrading."
      } elseif ($cmp -eq 0) {
        $shouldDownload = $false
        Write-Host "Local version matches latest ($version), skip download."
      } else {
        $shouldDownload = $false
        Write-Host "Local version $installedVersion is newer than latest $version, skip download."
      }
    } else {
      Write-Host "Binary already exists but current version could not be detected, downloading latest."
    }
  }

  $tmpFile = Join-Path $env:TEMP ("{0}-{1}.download" -f $BinaryName, [Guid]::NewGuid().ToString("N"))

  if ($shouldDownload) {
    Write-Host "Downloading CLI v$version from: $downloadUrl"
    Download-FileWithCacheBust -DownloadUrl $downloadUrl -OutputPath $tmpFile -ExpectedSha256 $sha256

    if (-not [string]::IsNullOrWhiteSpace($sha256)) {
      $actualHash = (Get-FileHash -Path $tmpFile -Algorithm SHA256).Hash.ToLowerInvariant()
      if ($actualHash -ne $sha256) {
        Remove-Item -Path $tmpFile -Force -ErrorAction SilentlyContinue
        throw "SHA256 mismatch. expected=$sha256 actual=$actualHash"
      }
    } else {
      Write-Host "Warning: no sha256 in manifest, checksum verification skipped."
    }

    Move-Item -Path $tmpFile -Destination $targetFile -Force
  }

  $userPath = [Environment]::GetEnvironmentVariable("Path", "User")
  if (-not $userPath) {
    $userPath = ""
  }

  $segments = Get-PathSegmentsLower -PathValue $userPath
  $installDirNormalized = $InstallDir.TrimEnd("\\").ToLowerInvariant()
  $alreadyInPath = $false
  foreach ($segment in $segments) {
    if ($segment -eq $installDirNormalized) {
      $alreadyInPath = $true
      break
    }
  }

  if (-not $alreadyInPath) {
    $newPath = if ([string]::IsNullOrWhiteSpace($userPath)) { $InstallDir } else { "$userPath;$InstallDir" }
    [Environment]::SetEnvironmentVariable("Path", $newPath, "User")
    Write-Host "Updated user PATH with: $InstallDir"

    if ([string]::IsNullOrWhiteSpace($env:Path)) {
      $env:Path = $InstallDir
    } elseif (-not ((Get-PathSegmentsLower -PathValue $env:Path) -contains $installDirNormalized)) {
      $env:Path = "$env:Path;$InstallDir"
    }

    Write-Host "Updated current shell PATH with: $InstallDir"
  } else {
    if ([string]::IsNullOrWhiteSpace($env:Path)) {
      $env:Path = $InstallDir
      Write-Host "Updated current shell PATH with: $InstallDir"
    } elseif (-not ((Get-PathSegmentsLower -PathValue $env:Path) -contains $installDirNormalized)) {
      $env:Path = "$env:Path;$InstallDir"
      Write-Host "Updated current shell PATH with: $InstallDir"
    }
  }

  Write-Host "Installed: $targetFile"
  Write-Host "Version: $version"
  Write-Host "Run in current shell: $BinaryName --version"
  exit 0
} catch {
  $errorMessage = "Unknown installer error."
  $errorRecordText = ""
  $scriptStack = ""

  if ($null -ne $_) {
    if ($null -ne $_.Exception -and -not [string]::IsNullOrWhiteSpace($_.Exception.Message)) {
      $errorMessage = $_.Exception.Message
    } elseif (-not [string]::IsNullOrWhiteSpace([string]$_)) {
      $errorMessage = [string]$_
    }
  }

  [Console]::Error.WriteLine("[mediause-installer] $errorMessage")
  if (-not [string]::IsNullOrWhiteSpace($errorRecordText)) {
    [Console]::Error.WriteLine($errorRecordText)
  }

  exit 1
}
