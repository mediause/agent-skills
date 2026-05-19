---
name: fifa2026
description: Standardized fifa2026 skill for MediaUse. Includes Windows install, key onboarding, strict context/auth flow, full fifa2026 dynamic command map, and safe read-oriented execution controls.
---

# MediaUse FIFA 2026 Skill

Use this skill to run FIFA 2026 data discovery workflows in MediaUse, including player lookup, team lookup, group lookup, and detailed stats retrieval.

## Scope

Use this skill when the task targets `fifa2026` operations such as:

- Search player by name
- Search team by name
- Search group by letter/country (`query` optional)
- Get player details
- Get team details and roster preview
- Get player recent match stats
- Get team recent match stats

## 1. Install MediaUse CLI (Windows Only)

Use the official install script for Windows:

- https://release.mediause.dev/install.ps1

Run:

```powershell
powershell -C "iwr https://release.mediause.dev/install.ps1 -UseBasicParsing | iex"
```

Then verify:

```powershell
mediause --version
```

Current support status:

- Windows: supported
- Linux: not supported yet
- macOS: not supported yet

Recommended skill install path:

- .mediause/skills/fifa2026/SKILL.md

## 2. Get and Configure MediaUse Key

### 2.1 Apply for key

1. Open https://mediause.dev/
2. Sign in to your account.
3. Open Project.
4. Create or copy your API key.

### 2.2 Configure key in CLI

```powershell
mediause manage key <your_key> --json
```

## 3. Core Flow (Mandatory Order)

Always follow this order:

1. Discover site and commands.
2. Bind account context with `use account`.
3. Check status with `auth health` when needed.
4. Execute dynamic site actions.
5. Verify with trace/task.

### 3.1 Discover and plugin setup

```powershell
mediause plugin list --json
mediause plugin add fifa2026 --json
mediause fifa2026 -h
mediause fifa2026 search -h
mediause fifa2026 get -h
```

### 3.2 Bind context before commands

`use account` must be executed successfully before search/get actions.

`use account` argument format:

- `<platform:account_id>`
- `account_id` can be selected from `mediause auth list --json`.

```powershell
mediause auth list --json
mediause use account fifa2026:guest --json
```

If you need to watch page behavior (for challenge/manual checks):

```powershell
mediause use account fifa2026:guest --show --json
```

### 3.3 Auth health precondition

For `fifa2026` read workflows, `guest` is typically sufficient. If a non-guest account is used, check:

```powershell
mediause auth health --json
```

If health indicates login expired:

```powershell
mediause auth login fifa2026 --json
mediause use account fifa2026:<account_id> --json
mediause auth health --json
```

## 4. FIFA 2026 Dynamic Command Map (v1)

Source schema:

- plugin: `plugin.fifa2026`
- manifest: `crates/platforms/plugins/fifa2026/manifest.yaml`

### 4.1 search.*

- `mediause fifa2026 search player --name <text> [--limit <n>] --json`
- `mediause fifa2026 search team --name <text> [--url <url>] [--limit <n>] --json`
- `mediause fifa2026 search group [--query <text>] [--url <url>] [--limit <n>] --json`

`search group` query behavior:

- No `query`: return all groups.
- Letter query: supports values like `a`, `b`, `c`, or `a,b,c`.
- Country query: supports values like `brazil`, and returns matched group.

### 4.2 get.*

- `mediause fifa2026 get player --url <url> --json`
- `mediause fifa2026 get team --url <url> [--player-limit <n>] --json`
- `mediause fifa2026 get player-stats --url <url> [--limit <n>] --json`
- `mediause fifa2026 get team-stats --url <url> [--limit <n>] --json`

## 5. Operational Constraints (Mandatory)

Apply these constraints for stable and safe execution.

### 5.1 Read-oriented pacing

- Avoid burst loops on repeated navigation.
- Add short delay between repeated fetches.
- Stop and retry later if anti-bot/challenge appears.

### 5.2 Suggested limits and spacing

Suggested limits:

- Search/get actions: <= 60 per minute

Minimum spacing:

- Search/get actions: >= 1 second between actions

Same-target guardrails:

- Repeated request to same URL/query: >= 2 seconds

If a limit is hit or challenge repeats:

1. Pause at least 5 minutes.
2. Rebind context with `use account`.
3. Resume with lower frequency.

### 5.3 Safety policy

- Do not bypass platform protections.
- Do not attempt credential/session hijacking.
- Respect platform terms and local regulations.

### 5.4 Output and error handling

- Prefer `--json` output.
- Require structured error handling.
- On blocked/risk/challenge, stop and return actionable next steps.

## 6. Workflow Examples

### 6.1 Group overview (all groups)

```powershell
mediause use account fifa2026:guest --show --json
mediause fifa2026 search group --json
mediause trace last --json
```

### 6.2 Group lookup by letters

```powershell
mediause use account fifa2026:guest --json
mediause fifa2026 search group --query "a,b,c" --json
mediause trace last --json
```

### 6.3 Group lookup by country

```powershell
mediause use account fifa2026:guest --json
mediause fifa2026 search group --query "brazil" --json
mediause trace last --json
```

### 6.4 Player to stats drill-down

```powershell
mediause use account fifa2026:guest --json
mediause fifa2026 search player --name "marta" --limit 5 --json
mediause fifa2026 get player --url <player_url> --json
mediause fifa2026 get player-stats --url <player_url> --limit 5 --json
mediause trace last --json
```

## 7. Execution Checklist

Before run:

1. CLI installed via `https://release.mediause.dev/install.ps1` on Windows.
2. PATH updated and `mediause --version` works.
3. API key configured and verified.
4. Account context bound via `mediause use account <platform:account_id>`.
5. If using non-guest account, `mediause auth health --json` checked.

During run:

1. Respect spacing and retry limits.
2. Stop on repeated challenge pages.
3. Avoid repeated burst requests to same target.

After run:

1. Save logs and outcomes.
2. Record challenge/risk events and cooldowns.
3. Keep activity under conservative limits.

## 8. Quick Command Reference

```powershell
# discover
mediause plugin list --json
mediause plugin add fifa2026 --json
mediause fifa2026 -h
mediause fifa2026 search -h
mediause fifa2026 get -h

# context + status
mediause auth list --json
mediause use account fifa2026:guest --show --json
mediause auth health --json

# key workflows
mediause fifa2026 search group --json
mediause fifa2026 search group --query "a,b,c" --json
mediause fifa2026 search group --query "brazil" --json
mediause fifa2026 search team --name "brazil" --json
mediause fifa2026 get team --url <team_url> --json
mediause fifa2026 get team-stats --url <team_url> --json

# trace
mediause trace last --json
```

Skill Metadata
Maintainer: @mediause-demo
Last-Updated: 2026-05-20
Version: v1
