# MediaUse Skill Standardized Definition Guide (Reusable Template)

This document defines a reusable Skill standard structure with the goal of:

- Helping agents understand and reliably invoke the MediaUse CLI.
- Unifying installation, authentication, execution, constraints, and output formats across different site Skills.
- Enabling rapid generation of site Skills (such as weibo, xiaohongshu, chatgpt) from one shared template.

Applicable architecture: core command + site dynamic command.

## 1. Installation and Download

### 1.1 CLI Installation

Only Windows is currently supported. macOS and Linux are not yet supported.

Install the MediaUse CLI in the user's own secure environment using the official npm package:

```powershell
npm install -g @mediause/cli
mediause --version
```

If the CLI is already installed, run the version check again to confirm it is available in PATH.

### 1.2 Recommended Skill Installation Directory

It is recommended that each site Skill live in its own directory:

- .mediause/skills/<site>/SKILL.md
- .mediause/skills/<site>/examples/
- .mediause/skills/<site>/schema/

Notes:

- One Skill corresponds to one primary site.
- Common flows such as auth/use/trace/task should remain consistent.

## 2. Key Acquisition and Configuration (Auth / Key)

### 2.1 API Key Acquisition

If the workflow depends on cloud-side capabilities or gateway authentication, the user must first obtain an API Key.

Current standard acquisition flow:

1. Visit https://mediause.dev/
2. Complete account sign-in
3. Go to the Project page
4. Create or view an API key in the user's own secure environment under Project; never paste it into chat, logs, terminal history, or CLI commands.

The Skill should explicitly state:

- The source of the Key
- The scope of the Key (local / session / environment variable)
- The standard error message when the Key is missing or invalid

### 2.2 Safe Verification and Local Configuration

Before any site action, first run a read-only check to see whether a MediaUse API key is already configured:

```powershell
mediause manage key --json
```

This command is only for verification. Do not paste, echo, or print the secret value into chat, logs, terminal history, or the skill instructions. If the result shows no configured key, ask the user to set it in their own secure local environment or via the MediaUse app; never instruct the model to embed the API key directly into a CLI command or to copy it verbatim into a prompt.

### 2.3 Authentication Verification

```powershell
mediause auth list --json
mediause auth health --json
```

Execution constraints:

- `auth health` is only available after `use account` succeeds, and is used to query the login/authorization status of the current bound context.
- `use account` uses the format `<platform:account_id>`, where `account_id` can be obtained via `mediause auth list --json`.
- `use account` starts the context in hidden browser mode by default and does not actively display the browser window.
- If manual observation or takeover is required, use `mediause use account <site>:<account_id> --show --json` to display the browser.
- If `use account` has not been completed, `auth health` must not be called; first run `mediause use account <site>:<account_id> --json`.
- If `auth health` reports that the user is not logged in or authorization has expired, run `mediause auth login <site> --json`, then rerun `use account` and `auth health`.
- If the page shows `unusual traffic`, CAPTCHA, or risk-confirmation prompts, rerun `mediause use account <site>:<account_id> --show --json` to open the browser so a human can complete verification or confirmation; after that, follow-up tasks for the same account usually return to normal.

## 3. Command Introduction and Standard Invocation Flow (Core + Dynamic)

## 3.1 Core Common Commands (All Skills Must Support)

Each Skill document must at least cover the following core commands:

- mediause plugin list
- mediause plugin add <site>
- mediause auth login <platform>
- mediause use account <platform:account_id> [--policy]
- mediause use account <platform:account_id> [--policy] [--show]
- mediause auth health
- mediause trace last
- mediause task status --task-id <id>
- mediause task trace --task-id <id>
- mediause manage context --show|--close|--clear
- mediause --version or mediause -v

Optional mode:

- mediause use account <site>:guest (supported only by some sites)

## 3.2 Standard Workflow That Should Be Executed for Every Task

Strong preconditions:

- Only after `mediause use account <platform:account_id>` succeeds may read operations (get/search/user...) and write operations (post/reply/engage...) proceed.
- If `use account` has not completed, the Skill must stop the business command and return guidance.
- `use account` hides the browser by default; only use `--show` when manual observation, debugging, or CAPTCHA handling is needed.
- For sites that support guest mode, use `mediause use account <site>:guest` to enter guest mode; guest mode only allows read operations and not write or interaction actions.

A recommended five-step flow:

1. Discovery and checks: plugin list / plugin add / plugin help
2. Bind context: use account (must succeed)
3. Status check: auth health (if not logged in, run auth login, then use account + auth health again)
4. Execute action: site dynamic command
5. Trace and verify: trace/task

Guest mode branch:

- If the target site supports guest mode, use `mediause use account <site>:guest --json` in step 2.
- If guest mode encounters `unusual traffic` or CAPTCHA, switch to `mediause use account <site>:guest --show --json`, complete verification manually, then continue with read operations.
- Skip step 3 for guest mode.
- In guest mode, only read/fetch actions should be executed.
- When executing write actions such as post/reply/engage, the Skill must block and instruct the user to switch to a logged-in account.

Example:

```powershell
mediause plugin list --json
mediause plugin add weibo --json
mediause weibo -h
mediause weibo post -h
mediause use account weibo:<account_id> --policy balanced --json
mediause auth health --json
mediause auth login weibo --json
mediause use account weibo:<account_id> --policy balanced --json
mediause auth health --json
mediause weibo search hot --json
mediause trace last --json

# If unusual traffic or CAPTCHA appears, display the browser for manual handling
mediause use account weibo:<account_id> --policy balanced --show --json

# Guest mode (only if the site supports it)
mediause use account weibo:guest --json
mediause weibo search hot --json
```

## 3.3 Dynamic Command Description (Site Capabilities)

Site actions come from:

- crates/platforms/src/<site>/commands.json

Using weibo as an example, capability domains may include:

- post
- get
- user
- reply
- search
- engage

The Skill should only declare capabilities that already exist in the manifest; do not fabricate commands.

Parameter discovery rules:

- Use `mediause <site> -h` to view the site capability overview.
- Use `mediause <site> <capability> -h` to view actions and parameters under a capability.
- For example: `mediause weibo post -h`.
- A single-site Skill must provide a complete site command map (capability/action/args/examples) and keep it consistent with the help output.

Plugin acquisition rules:

- Use `mediause plugin list` to view currently supported sites.
- Use `mediause plugin add <site>` to install the corresponding site plugin.

Guest support rules:

- Guest mode is not universally available across all sites; it is only supported on some.
- A single-site Skill must explicitly declare whether guest mode is supported for that site.
- If guest mode is not supported, the Skill must instruct the user to use the standard login flow: `auth login <site>` + `use account <site>:<account>`.

## 4. Command Combination Examples and Workflow Design

This section defines practical command combinations that an agent can execute directly.

### 4.1 Workflow A: From Trend Discovery to Draft Publishing

```powershell
# A1. Login and context binding
mediause auth login weibo --json
mediause use account weibo:<account_id> --json

# A2. Fetch trends
mediause weibo search hot --json

# A3. Generate a draft (external LLM processing) and publish it
mediause weibo post feed --text "<draft_text>" --media c:/tmp/a.png --json

# A4. Verify
mediause trace last --json
```

### 4.2 Workflow B: Monitoring + Interaction Loop

```powershell
mediause use account weibo:<account_id> --json
mediause weibo get notif --type mention --json
mediause weibo reply comment --post-id <id> --text "Received, thank you" --json
mediause trace last --json
```

### 4.3 Workflow C: User Operations

```powershell
mediause use account weibo:<account_id> --json
mediause weibo user followers --user-id <uid> --limit 20 --json
mediause weibo engage follow --user-id <uid> --json
mediause trace last --json
```

## 5. Usage Constraints and Compliance Strategy (Guardrails)

Each Skill must contain and enable the following policies by default.

### 5.1 Content Safety and Business Constraints

- Do not generate illegal, infringing, hateful, or harassing content.
- Add human confirmation steps for high-risk content such as medical, financial, or recruiting material.

### 5.2 Failure Handling

- Must return structured errors (`error_code`, `message`, `suggestion`).
- Prefer `--json` for invocation so agents can retry and make branch decisions.
- If the failure is due to `unusual traffic`, CAPTCHA, or a manual confirmation requirement, the Skill should explicitly instruct the user to run `mediause use account <site>:<account_id> --show --json` to open the browser and resolve it.

## 6. Standardized Skill Document Structure (Strong Constraints)

It is recommended that each site Skill follow this fixed section layout:

1. Skill metadata
2. Installation
3. Key configuration
4. Core commands
5. Site commands (from commands.json)
6. Standard workflows
7. Constraints and rate controls
8. Error codes and recovery
9. Minimum validation checklist

Document encoding constraints:

- `SKILL.md` must use UTF-8 without BOM.
- UTF-8 BOM, UTF-16, GBK, and other encodings are prohibited.
- This is intended to ensure that `npx skills add` can reliably recognize all skills.

## 7. Skill Template (Ready to Copy)

Template storage requirements:

- The file must be saved as UTF-8 without BOM.

```markdown
---
name: mediause-<site>
description: Standardized MediaUse skill for <site> automation.
allowed-tools: Bash(MediaUse:*)
---

# 1. Install
- binary source:
- local path:

# 2. Key Setup
- MEDIAUSE_API_KEY:
- mediause manage key:

# 3. Core Commands
- plugin list
- auth login
- use account
- auth health
- trace/task

# 4. Site Commands
- source manifest: crates/platforms/src/<site>/commands.json
- supported capabilities:

# 5. Workflows
- workflow-a:
- workflow-b:


# 6. Recovery
- common errors
- retry strategy
```

## 8. How to Generate Site Skills in Bulk Based on This Standard

Suggested generation flow:

1. Read the target site manifest.yaml
2. Extract capability/action/args and risk_level
3. Fill the Site Commands and Workflow examples of the Skill template
4. Inject common guardrails (anti-spam, rate limiting, compliance)
5. Perform an executable validation pass (at least 1 read + 1 write + trace)

This ensures:

- Different site Skills have a consistent structure.
- Agents can form stable invocation strategies.
- New site onboarding costs are reduced and documentation quality is controlled.

## 9. Minimum Acceptance Checklist (Definition of Done)

- Contains the five core parts: installation, key setup, core workflow, workflows, and constraints.
- All site actions come from the corresponding manifest.yaml.
- Provides at least two end-to-end workflows.
- Example commands can be run directly (preferably all with `--json`).
- The document encoding is UTF-8 without BOM so it can be fully recognized by `npx skills add`.

## Required fields:

- Maintainer: <name or handle>
- Last-Updated: <YYYY-MM-DD>
- Version: <skill version, for example v1>

Recommended block format:

```text
Skill Metadata
Maintainer: @your-handle
Last-Updated: 2026-04-23
Version: v1
```
