---
name: mediause-google
description: Standardized Google skill for MediaUse. Includes Windows install, key onboarding, strict context/auth flow, full Google dynamic command map, and safety/rate controls.
---

# MediaUse Google Skill

This skill defines the standardized workflow for running Google search and discovery automation through MediaUse.

## Scope

Use this skill when the task targets Google operations such as:

- Account: health check
- Search: web results, query suggestions
- Get: news headlines, daily trends

## 1. Install MediaUse CLI (Windows Only)

Use the official install script for Windows:

- https://release.mediause.dev/install.ps1

Run:

```powershell
powershell -C "iwr https://release.mediause.dev/install.ps1 -UseBasicParsing | iex"
```

Then verify in the same shell:

```powershell
mediause --version
```

Current support status:

- Windows: supported
- Linux: not supported yet
- macOS: not supported yet

Recommended skill install path:

- .mediause/skills/google/SKILL.md

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
3. Check status with `auth health`.
4. Execute dynamic site actions.
5. Verify with trace/task.

### 3.1 Discover and plugin setup

```powershell
mediause plugin list --json
mediause plugin add google --json
mediause google -h
mediause google search -h
```

### 3.2 Bind context before any read/write

`use account` must be executed successfully before any fetch/read action.

`use account` argument format:

- `<platform:account_id>`
- `account_id` should be selected from `mediause auth list --json`.

Google manifest default account id is `guest`.

```powershell
mediause auth list --json
mediause use account google:guest --policy balanced --json
```

### 3.3 Auth health precondition

`auth health` is valid only after successful `use account`.

```powershell
mediause auth health --json
```

If `auth health` indicates not logged in/expired for a non-guest account:

```powershell
mediause auth login google --json
mediause use account google:main --policy balanced --json
mediause auth health --json
```

### 3.4 Guest mode

Google plugin exposes `guest` as the default account context.

```powershell
mediause use account google:guest --json
```

Guest mode rules:

- Read-only operations only.
- This plugin command set does not include write operations.

## 4. Google Dynamic Command Map (v1)

Source schema:

- plugin: `plugin.google`
- manifest: `crates/platforms/plugins/google/manifest.yaml`

### 4.1 account.*

- `mediause google account health --json`

### 4.2 search.*

- `mediause google search web --keyword <keyword> [--limit <n>] [--lang <lang>] --json`
- `mediause google search suggest --keyword <keyword> [--lang <lang>] --json`

### 4.3 get.*

- `mediause google get news [--keyword <keyword>] [--limit <n>] [--lang <lang>] [--region <region>] --json`
- `mediause google get trends [--region <region>] [--limit <n>] --json`

## 5. Operational Constraints (Mandatory)

Apply these constraints for all actions to reduce risk and keep behavior stable.

### 5.1 Human-like pacing

- Avoid tight polling loops.
- Add randomized delay between repeated reads/searches.
- Mix different read actions instead of repeatedly hitting one endpoint.

### 5.2 Frequency limits and minimum spacing

- Hard stop if operation rate is abnormally high.
- Stop immediately on repeated anti-bot challenge or risk prompt.

Suggested limits:

- Search/get/account read actions: <= 60 per minute

Minimum spacing:

- Search/get/account read actions: >= 1 second between actions

Same-target guardrails:

- Repeated query on the same keyword/region pair: >= 3 seconds

If a limit is hit:

1. Pause at least 5 minutes.
2. Resume with lower request frequency.
3. Re-check session health if account context changed.

### 5.3 Safety policy

- Do not bypass platform protections.
- Do not attempt credential scraping or session hijacking.
- Respect platform terms and local regulations.

### 5.4 Output and error handling

- Prefer `--json` output for machine workflows.
- Require structured error handling with stable fields/code when available.
- On blocked/rate-limit/risk prompt, stop and return actionable next steps.

## 6. Workflow Examples

### 6.1 Web search to news follow-up

```powershell
mediause use account google:guest --json
mediause auth health --json
mediause google search web --keyword "agent browser" --limit 10 --lang en --json
mediause google get news --keyword "agent browser" --limit 10 --lang en --region US --json
mediause trace last --json
```

### 6.2 Trends and suggestions loop

```powershell
mediause use account google:guest --json
mediause auth health --json
mediause google get trends --region US --limit 20 --json
mediause google search suggest --keyword "ai coding" --lang en --json
mediause trace last --json
```

### 6.3 Account health check branch

```powershell
mediause use account google:guest --json
mediause auth health --json
mediause google account health --json
mediause trace last --json
```

## 7. Execution Checklist

Before run:

1. CLI installed via `https://release.mediause.dev/install.ps1` on Windows.
2. PATH updated and `mediause --version` works.
3. API key configured and verified.
4. Account context bound via `mediause use account <platform:account_id>`.
5. `mediause auth health --json` checked after context bind.
6. If non-guest account is used and not logged in, run `mediause auth login google --json` and re-bind context.
7. Pacing policy is enabled.

During run:

1. Respect delays and minimum spacing.
2. Stop on anti-bot/risk prompts.
3. Avoid repetitive burst loops.

After run:

1. Save logs and outcomes.
2. Record any risk warning and cooldown events.
3. Keep activity under conservative limits.

## 8. Quick Command Reference

```powershell
# discover
mediause plugin list --json
mediause plugin add google --json
mediause google -h
mediause google search -h

# context + status
mediause auth list --json
mediause use account google:guest --json
mediause auth health --json

# read actions
mediause google search web --keyword "open source" --limit 10 --json
mediause google search suggest --keyword "open source" --json
mediause google get news --keyword "open source" --limit 10 --json
mediause google get trends --region US --limit 20 --json

# account health + trace
mediause google account health --json
mediause trace last --json
```

Skill Metadata
Maintainer: @mediause-team
Last-Updated: 2026-05-11
Version: v1
