---
name: linkedin
description: Use when handling MediaUse LinkedIn automation tasks, including jobs and people search, timeline and inbox retrieval, profile reads, safe connect/message flows, and Sales Navigator workflows, with Windows install, key onboarding, strict context/auth flow, full dynamic command map, and safety/rate controls.
---

# MediaUse LinkedIn Skill

Operate LinkedIn workflows with a consistent setup for search, profile intelligence, inbox/thread reads, and guarded outreach actions.

## Scope

Use this skill when the task targets LinkedIn operations such as:

- Search: jobs, people, sales navigator leads
- Read: timeline, inbox, thread snapshot, job detail, jobs preferences, sent invitations, services page
- Profile: read, experience, projects, analytics
- Post analytics: summarize visible post counters
- Outreach: safe connect, safe send message
- Sales Navigator: inbox, message, thread

## 1. Install MediaUse CLI (Windows Only)

Use the official install script for Windows:

- https://release.mediause.dev/install.ps1
Mandatory update rule:

- Before every run, execute the install script once to auto-install or auto-upgrade to the latest MediaUse CLI.

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

- .mediause/skills/linkedin/SKILL.md

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

First step on every run: execute install script once to auto-install or auto-upgrade the latest MediaUse CLI.

1. Discover site and commands.
2. Bind account context with use account.
3. Check status with auth health.
4. Execute LinkedIn dynamic actions.
5. Verify with trace/task.

### 3.1 Discover and plugin setup

```powershell
mediause plugin list --json
mediause plugin add linkedin --json
mediause linkedin -h
mediause linkedin search -h
mediause linkedin get -h
```

### 3.2 Bind context before actions

use account must be executed successfully before any read/write action.

use account argument format:

- <platform:account_id>
- account_id should be selected from mediause auth list --json.

```powershell
mediause auth list --json
mediause use account linkedin:<account_id> --policy balanced --json
```

If challenge/risk prompts appear, reopen in visible mode:

```powershell
mediause use account linkedin:<account_id> --policy balanced --show --json
```

### 3.3 Auth health precondition

auth health is valid only after successful use account.

```powershell
mediause auth health --json
```

If auth health indicates not logged in/expired:

```powershell
mediause auth login linkedin --json
mediause use account linkedin:<account_id> --policy balanced --json
mediause auth health --json
```

## 4. LinkedIn Dynamic Command Map (v1)

Source schema:

- plugin: plugin.linkedin
- manifest: crates/platforms/plugins/linkedin/manifest.yaml

### 4.1 account.*

- mediause linkedin account health --json

### 4.2 search.*

- mediause linkedin search jobs --query <text> [--location <text>] [--limit <n>] --json
- mediause linkedin search people --keywords <text> [--limit <n>] --json
- mediause linkedin search salesnav --keywords <text> [--limit <n>] --json

### 4.3 get.*

- mediause linkedin get timeline [--limit <n>] --json
- mediause linkedin get inbox [--limit <n>] [--unread-only <bool>] --json
- mediause linkedin get job-detail --job-url <url> --json
- mediause linkedin get jobs-preferences --json
- mediause linkedin get sent-invitations --json
- mediause linkedin get services-read [--profile-url <url>] [--services-url <url>] --json
- mediause linkedin get thread-snapshot --thread-url <url> [--max-scrolls <n>] --json

### 4.4 profile.*

- mediause linkedin profile read [--profile-url <url>] --json
- mediause linkedin profile experience [--profile-url <url>] --json
- mediause linkedin profile projects [--profile-url <url>] --json
- mediause linkedin profile analytics [--profile-url <url>] --json

### 4.5 post.*

- mediause linkedin post analytics [--profile-url <url>] [--limit <n>] --json

### 4.6 engage.*

- mediause linkedin engage connect --profile-url <url> --expected-name <text> [--note <text>] [--send <bool>] --json

### 4.7 message.*

- mediause linkedin message safe-send --thread-url <url> --expected-name <text> --message <text> [--expected-last-text <text>] [--send <bool>] --json

### 4.8 salesnav.*

- mediause linkedin salesnav inbox [--limit <n>] [--unread-only <bool>] --json
- mediause linkedin salesnav message --recipient <text> --subject <text> --body <text> [--send <bool>] --json
- mediause linkedin salesnav thread --thread-or-recipient <text> [--limit <n>] --json

## 5. Operational Constraints (Mandatory)

Apply these constraints for all actions to reduce risk and keep behavior stable.

### 5.1 Human-like pacing

- Avoid tight polling loops.
- Add randomized delay between repeated actions.
- Mix read and write operations to reduce repetitive behavior signals.

### 5.2 Frequency limits and minimum spacing

- Hard stop if operation rate is abnormally high.
- Stop immediately on repeated challenge/risk prompts.

Suggested limits:

- Search/read/profile/post analytics: <= 60 per minute
- Connect and safe-send: <= 20 per hour
- Sales Navigator message send: <= 20 per hour

Minimum spacing:

- Search/read/profile/post analytics: >= 1 second between actions
- Connect and safe-send: >= 20 seconds between actions
- Sales Navigator message send: >= 20 seconds between actions

Same-target guardrails:

- Repeated connect/message on same recipient/thread: >= 60 seconds

If a limit is hit:

1. Pause at least 10 minutes.
2. Resume with read-only actions first.
3. Re-check context health before write actions.

### 5.3 Safety policy

- Do not bypass platform protections.
- Do not attempt credential scraping or session hijacking.
- Respect platform terms and local regulations.
- Keep fail-closed behavior for connect and safe-send actions.

### 5.4 Output and error handling

- Prefer --json output for machine workflows.
- Require structured error handling with stable fields/code when available.
- On challenge/auth wall, stop and return actionable next steps.

## 6. Workflow Examples

### 6.1 Jobs pipeline

```powershell
mediause use account linkedin:<account_id> --json
mediause auth health --json
mediause linkedin search jobs --query "staff software engineer" --location "Singapore" --limit 20 --json
mediause linkedin get job-detail --job-url <job_url> --json
mediause trace last --json
```

### 6.2 People search to safe connect

```powershell
mediause use account linkedin:<account_id> --json
mediause auth health --json
mediause linkedin search people --keywords "founder saas singapore" --limit 10 --json
mediause linkedin engage connect --profile-url <profile_url> --expected-name "<full_name>" --note "Hi, great to connect." --send false --json
mediause trace last --json
```

### 6.3 Inbox thread safe-send

```powershell
mediause use account linkedin:<account_id> --json
mediause auth health --json
mediause linkedin get inbox --limit 20 --unread-only true --json
mediause linkedin message safe-send --thread-url <thread_url> --expected-name "<recipient_name>" --message "Thanks for your reply." --send false --json
mediause trace last --json
```

### 6.4 Sales Navigator flow

```powershell
mediause use account linkedin:<account_id> --json
mediause auth health --json
mediause linkedin search salesnav --keywords "qa manager food" --limit 25 --json
mediause linkedin salesnav thread --thread-or-recipient <thread_or_recipient> --limit 50 --json
mediause trace last --json
```

## 7. Execution Checklist

Before run:

Before every run, execute the install script once.

1. CLI installed via https://release.mediause.dev/install.ps1 on Windows.
2. PATH updated and mediause --version works.
3. API key configured and verified.
4. Account context bound via mediause use account <platform:account_id>.
5. auth health checked after context bind.
6. If not logged in, run mediause auth login linkedin --json and re-bind context.
7. Pacing policy is enabled.

During run:

1. Respect delays and minimum spacing.
2. Stop on anti-bot/challenge prompts.
3. Keep connect/safe-send in dry-run first when possible.

After run:

1. Save logs and outcomes.
2. Record risk warnings and cooldown events.
3. Keep activity under conservative limits.

## 8. Quick Command Reference

```powershell
# always run once before each workflow (auto-upgrade latest)
powershell -C "iwr https://release.mediause.dev/install.ps1 -UseBasicParsing | iex"
mediause --version

# discover
mediause plugin list --json
mediause plugin add linkedin --json
mediause linkedin -h
mediause linkedin search -h
mediause linkedin get -h

# context + status
mediause auth list --json
mediause use account linkedin:<account_id> --json
mediause auth health --json

# key actions
mediause linkedin search jobs --query "data engineer" --limit 10 --json
mediause linkedin search people --keywords "product manager" --limit 10 --json
mediause linkedin get timeline --limit 20 --json
mediause linkedin engage connect --profile-url <profile_url> --expected-name "<name>" --send false --json
mediause linkedin message safe-send --thread-url <thread_url> --expected-name "<name>" --message "hello" --send false --json

# trace
mediause trace last --json
```

Skill Metadata
Maintainer: @mediause-team
Last-Updated: 2026-06-09
Version: v1
