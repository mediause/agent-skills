import { readdir, readFile, writeFile } from "node:fs/promises"
import { execFile } from "node:child_process"
import path from "node:path"
import process from "node:process"
import { promisify } from "node:util"

const repoRoot = path.resolve(process.cwd())
const repoUrl = "https://github.com/mediause/agent-skills"
const rawBaseUrl = "https://raw.githubusercontent.com/mediause/agent-skills/main"
const ignoredEntries = new Set([".git", ".github", "scripts"])
const execFileAsync = promisify(execFile)

function parseFrontmatter(content) {
  const normalizedContent = content.replace(/\r\n/g, "\n")

  if (!normalizedContent.startsWith("---\n")) {
    return { data: {}, body: content }
  }

  const endIndex = normalizedContent.indexOf("\n---\n", 4)
  if (endIndex === -1) {
    return { data: {}, body: content }
  }

  const rawFrontmatter = normalizedContent.slice(4, endIndex)
  const body = normalizedContent.slice(endIndex + 5)
  const data = {}

  for (const line of rawFrontmatter.split(/\r?\n/)) {
    const separatorIndex = line.indexOf(":")
    if (separatorIndex === -1) {
      continue
    }

    const key = line.slice(0, separatorIndex).trim()
    let value = line.slice(separatorIndex + 1).trim()

    if ((value.startsWith('"') && value.endsWith('"')) || (value.startsWith("'") && value.endsWith("'"))) {
      value = value.slice(1, -1)
    }

    if (key) {
      data[key] = value
    }
  }

  return { data, body }
}

function extractTitle(markdownBody, fallbackTitle) {
  const headingMatch = markdownBody.match(/^#\s+(.+)$/m)
  return headingMatch?.[1]?.trim() || fallbackTitle
}

function extractSummary(markdownBody, fallbackSummary) {
  const lines = markdownBody
    .split(/\r?\n/)
    .map((line) => line.trim())
    .filter(Boolean)

  for (const line of lines) {
    if (line.startsWith("#")) {
      continue
    }
    if (line.startsWith("```")) {
      continue
    }
    if (line.startsWith("-") || line.startsWith("*") || /^\d+\./.test(line)) {
      continue
    }
    return line
  }

  return fallbackSummary
}

function extractMaintainerMetadata(markdownBody) {
  const maintainer = markdownBody.match(/^Maintainer:\s*(.+)$/m)?.[1]?.trim()
  const lastUpdated = markdownBody.match(/^Last-Updated:\s*(.+)$/m)?.[1]?.trim()
  const version = markdownBody.match(/^Version:\s*(.+)$/m)?.[1]?.trim()

  return {
    maintainer: maintainer || null,
    lastUpdated: lastUpdated || null,
    version: version || null,
  }
}

async function resolveLastUpdated(pluginName, metadataLastUpdated) {
  if (metadataLastUpdated) {
    return metadataLastUpdated
  }

  const skillSourcePath = `${pluginName}/SKILL.md`

  try {
    const { stdout } = await execFileAsync(
      "git",
      ["log", "-1", "--format=%cI", "--", skillSourcePath],
      { cwd: repoRoot },
    )

    const checkinTime = stdout.trim()
    if (checkinTime) {
      return checkinTime
    }
  } catch {
    // Fall through to deterministic fallback below.
  }

  return new Date().toISOString()
}

async function collectSkills() {
  const entries = await readdir(repoRoot, { withFileTypes: true })
  const skills = []

  for (const entry of entries) {
    if (!entry.isDirectory()) {
      continue
    }

    if (ignoredEntries.has(entry.name)) {
      continue
    }

    const skillPath = path.join(repoRoot, entry.name, "SKILL.md")

    try {
      const rawContent = await readFile(skillPath, "utf8")
      const { data, body } = parseFrontmatter(rawContent)
      const pluginName = entry.name
      const titleFallback = data.name || pluginName
      const summaryFallback = data.description || ""
      const metadata = extractMaintainerMetadata(body)
      const lastUpdated = await resolveLastUpdated(pluginName, metadata.lastUpdated)

      skills.push({
        pluginName,
        slug: pluginName,
        title: extractTitle(body, titleFallback),
        summary: extractSummary(body, summaryFallback),
        frontmatterName: data.name || null,
        description: data.description || "",
        sourcePath: `${pluginName}/SKILL.md`,
        repoUrl: `${repoUrl}/blob/main/${pluginName}/SKILL.md`,
        rawUrl: `${rawBaseUrl}/${pluginName}/SKILL.md`,
        maintainer: metadata.maintainer,
        lastUpdated,
        version: metadata.version,
      })
    } catch {
      continue
    }
  }

  return skills.sort((left, right) => left.pluginName.localeCompare(right.pluginName))
}

async function main() {
  const skills = await collectSkills()
  const output = {
    schemaVersion: 1,
    generatedAt: new Date().toISOString(),
    sourceRepo: repoUrl,
    mappingKey: "pluginName",
    skills,
  }

  const outputPath = path.join(repoRoot, "skills-index.json")
  await writeFile(outputPath, `${JSON.stringify(output, null, 2)}\n`, "utf8")

  console.log(`Generated ${skills.length} skills into ${outputPath}`)
}

main().catch((error) => {
  console.error(error)
  process.exitCode = 1
})