
<pre>
███╗   ███╗███████╗██████╗ ██╗ █████╗ ██╗   ██╗███████╗███████╗
████╗ ████║██╔════╝██╔══██╗██║██╔══██╗██║   ██║██╔════╝██╔════╝
██╔████╔██║█████╗  ██║  ██║██║███████║██║   ██║███████╗█████╗  
██║╚██╔╝██║██╔══╝  ██║  ██║██║██╔══██║██║   ██║╚════██║██╔══╝  
██║ ╚═╝ ██║███████╗██████╔╝██║██║  ██║╚██████╔╝███████║███████╗
╚═╝     ╚═╝╚══════╝╚═════╝ ╚═╝╚═╝  ╚═╝ ╚═════╝ ╚══════╝╚══════╝
</pre>

# MediaUse Agent Skills

MediaUse is a general Web CLI infrastructure for AI agents. It combines a browser kernel, CDP execution, and site plugins so agents can call business-level actions such as `post.feed`, `search.hot`, and `get.detail` instead of repeatedly planning low-level page actions.

## What MediaUse Is

MediaUse is designed for production web automation where repeatability, auditability, and account safety matter.

Core ideas:

- Semantic actions first: expose business outcomes, not click-by-click primitives
- Pluginized site knowledge: selectors, constraints, and workflows are assets in plugins
- CDP-native execution: deterministic browser execution without step-by-step vision loops
- Unified interfaces: CLI, Skill, and MCP map to the same JSON-RPC action model

In short: the agent decides what to do, MediaUse decides how to do it reliably on each site.

<img width="1195" height="896" alt="Image_aoc32xaoc32xaoc3" src="https://github.com/user-attachments/assets/4778c785-ad75-4616-9c00-c301f9db2ec0" />

<p align="center" width="100%">
<video src="https://github.com/user-attachments/assets/c4c0c494-2d6d-4164-9839-7950928a1085" width="80%" controls title="CLI example"></video>
</p>



## How Agents Use MediaUse

The recommended integration flow is:

1. Install the skill pack:
	- `npx skills add mediause/agent-skills`
2. Pick a site capability (for example, `weibov2 post feed`).
3. Ensure account context is set (`mediause use account ...`) when login is required.
4. Run one semantic action command with structured output (`--json`).
5. Use returned result fields (`success`, `data`, error metadata, trace info) for next-step decisions.

Typical command pattern:

```bash
mediause <site> <capability> <action> [args] --json
```

Examples:

```bash
mediause auth login weibov2
mediause use account weibov2:main
mediause weibov2 post feed --text "hello world" --json
mediause xiaohongshu search hot --limit 20 --json
mediause reddit get detail --url "https://www.reddit.com/..." --json
```

## How To Use The Skills In This Repository

Each site skill is a standardized instruction document at `<pluginName>/SKILL.md`.

These skills are intended to work consistently across agent runtimes such as:

- Claude Code
- Codex
- OpenClaw
- Cursor

Each skill defines:

- Install and setup expectations
- Account and auth flow requirements
- Dynamic command map aligned to actual MediaUse CLI capability
- Workflow examples with safe pacing and guardrails

For authoring and updates, the canonical template is:

- `SKILL_STANDARD_DEFINITION_ZH.md`

## Current Supported Sites

The current skill set (from `skills-index.json`) includes:

- arxiv
- bloomberg
- chatgpt
- douyinv2
- fifa2026
- google
- hackernews
- huggingface
- instagram
- reddit
- weibov2
- xiaohongshu

## Repository Contract

### Source Of Truth

- Every site skill lives at `<pluginName>/SKILL.md`.
- Folder name is the stable discovery key (`pluginName`).
- `pluginId` is not part of this repository sync contract.

### Sync Output

- `skills-index.json` is generated and should not be edited manually.
- Downstream consumers map and discover skills by `pluginName`.

### Compatibility Contract

All site skills must keep consistent behavior across agent environments:

1. Same CLI syntax
2. Same context and auth preconditions
3. Same guardrails and pacing constraints
4. Same error handling expectations

Do not introduce runtime-specific command variants in one skill file.

## Adding Or Updating A Site Skill

When a new MediaUse site plugin is introduced, add the matching skill in the same change set.

Required process:

1. Read `SKILL_STANDARD_DEFINITION_ZH.md`.
2. Inspect the current command surface from the MediaUse CLI and plugin runtime (site help, runnable commands, and JSON outputs).
3. Create or update `<pluginName>/SKILL.md`.
4. Build the command map from currently supported CLI commands only.
5. Keep workflow examples, guardrails, and timing constraints accurate.
6. Ensure no skill command exceeds current CLI capability.

Required attribution block at the end of each skill:

```text
Skill Metadata
Maintainer: @your-handle
Last-Updated: 2026-04-23
Version: v1
```
