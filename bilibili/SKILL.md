---
name: bilibili
description: MediaUse bilibili skill usage guide. Includes full bilibili manifest command map, parameter guidance, and executable examples for search/get/read/user/collection/engage flows.
---

# MediaUse Bilibili Skill

该 Skill 是 bilibili 插件的总览与使用说明，帮助用户快速完成“发现命令 -> 选择参数 -> 执行任务 -> 回溯结果”的完整操作。

Summary：

- 覆盖 bilibili manifest.yaml 中全部 capability 与 action（account/search/get/read/user/collection/engage）。
- 提供分组命令写法、关键参数速查和可复制的工作流示例。
- 面向实际使用场景设计，不限制固定调用顺序，用户可按任务目标自由组合命令。

## Scope

适用场景：

- 视频搜索与用户搜索
- 热门/排行榜/历史/关注动态拉取
- 视频详情、字幕、AI 摘要、评论读取
- 当前用户与指定用户数据读取
- 收藏夹内容读取
- 评论发布/回复（可选 execute 控制）

## 1. Install MediaUse CLI (Windows)

```powershell
powershell -C "iwr https://release.mediause.dev/install.ps1 -UseBasicParsing | iex"
mediause --version
```

## 2. Key & Account Context

```powershell
mediause manage key <your_key> --json
mediause auth list --json
mediause use account bilibili:<account_id> --json
mediause auth health --json
```

如需人工观察浏览器：

```powershell
mediause use account bilibili:<account_id> --show --json
```

可选 guest：

```powershell
mediause use account bilibili:guest --json
```

## 3. 快速发现命令

```powershell
mediause plugin list --json
mediause plugin add bilibili --json
mediause bilibili -h
mediause bilibili account -h
mediause bilibili search -h
mediause bilibili get -h
mediause bilibili read -h
mediause bilibili user -h
mediause bilibili collection -h
mediause bilibili engage -h
```

## 4. Bilibili Site Command Map（Full）

来源：`crates/platforms/plugins/bilibili/manifest.yaml`

### 4.1 capability 总览

- `account`: `health`
- `search`: `video`, `user`
- `get`: `dynamic`, `hot`, `ranking`, `history`, `feed`
- `read`: `feed-detail`, `video`, `subtitle`, `summary`, `comments`, `dynamic`
- `user`: `me`, `profile`, `following`, `videos`, `feed`
- `collection`: `favorite`
- `engage`: `comment`

### 4.2 分组用法（按 capability）

```powershell
# account
mediause bilibili account health --json

# search
mediause bilibili search video --query <text> [--page <n>] [--limit <n>] --json
mediause bilibili search user --query <text> [--page <n>] [--limit <n>] --json

# get
mediause bilibili get dynamic [--limit <n>] --json
mediause bilibili get hot [--limit <n>] --json
mediause bilibili get ranking [--limit <n>] --json
mediause bilibili get history [--limit <n>] --json
mediause bilibili get feed [--type <text>] [--pages <n>] [--limit <n>] --json

# read
mediause bilibili read feed-detail --id <dynamic_id> --json
mediause bilibili read video --bvid <bvid> --json
mediause bilibili read subtitle --bvid <bvid> [--lang <code>] --json
mediause bilibili read summary --bvid <bvid> --json
mediause bilibili read comments --bvid <bvid> [--parent <id>] [--limit <n>] --json
mediause bilibili read dynamic --id <dynamic_id> --json

# user
mediause bilibili user me --json
mediause bilibili user profile [--uid <uid>] [--me <true|false>] --json
mediause bilibili user following [--uid <uid>] [--page <n>] [--limit <n>] --json
mediause bilibili user videos --uid <uid> [--order <text>] [--page <n>] [--limit <n>] --json
mediause bilibili user feed --uid <uid> [--type <text>] [--pages <n>] [--limit <n>] --json

# collection
mediause bilibili collection favorite [--fid <id>] [--page <n>] [--limit <n>] --json

# engage
mediause bilibili engage comment --bvid <bvid> --text <text> [--parent <id>] [--execute <true|false>] --json
```

### 4.3 关键参数速查

- 通用分页参数：`page`, `pages`, `limit`
- 视频主键：`bvid`
- 动态主键：`id`
- 用户主键：`uid`
- 评论回复参数：`parent`
- 评论执行开关：`execute`（`false` 常用于预览参数，`true` 用于实际提交）

## 5. Workflow Examples

### 5.1 搜索视频并读取详情

```powershell
mediause use account bilibili:<account_id> --json
mediause bilibili search video --query "A股" --limit 5 --json
mediause bilibili read video --bvid <bvid> --json
mediause bilibili read summary --bvid <bvid> --json
mediause trace last --json
```

### 5.2 获取关注动态并读取动态详情

```powershell
mediause use account bilibili:<account_id> --json
mediause bilibili get feed --type all --pages 1 --limit 20 --json
mediause bilibili read dynamic --id <dynamic_id> --json
mediause bilibili read feed-detail --id <dynamic_id> --json
mediause trace last --json
```

### 5.3 用户画像与投稿列表

```powershell
mediause use account bilibili:<account_id> --json
mediause bilibili user profile --uid <uid> --json
mediause bilibili user videos --uid <uid> --order pubdate --limit 10 --json
mediause bilibili user following --uid <uid> --limit 20 --json
mediause trace last --json
```

### 5.4 评论读取与回复

```powershell
mediause use account bilibili:<account_id> --json
mediause bilibili read comments --bvid <bvid> --limit 20 --json
mediause bilibili engage comment --bvid <bvid> --text "谢谢分享" --execute false --json
mediause bilibili engage comment --bvid <bvid> --text "谢谢分享" --execute true --json
mediause trace last --json
```

## 6. Guardrails

- 遵守平台规则与当地法规。
- 不绕过验证码、风控或封禁机制。
- 不进行垃圾信息、诈骗、骚扰、仇恨、侵权等内容生成或投放。
- 建议优先使用 `--json` 便于自动化处理。
- 若遇到 `unusual traffic`、验证码或人工确认页面，建议使用 `--show` 人工处理后再继续。

## 7. Quick Reference

```powershell
# install/update
powershell -C "iwr https://release.mediause.dev/install.ps1 -UseBasicParsing | iex"
mediause --version

# discover
mediause plugin list --json
mediause plugin add bilibili --json
mediause bilibili -h
mediause bilibili read -h

# context
mediause auth list --json
mediause use account bilibili:<account_id> --json
mediause auth health --json

# common reads
mediause bilibili get hot --json
mediause bilibili read video --bvid <bvid> --json
mediause bilibili read subtitle --bvid <bvid> --lang zh-CN --json
mediause bilibili read summary --bvid <bvid> --json
mediause bilibili read comments --bvid <bvid> --json

# write (optional)
mediause bilibili engage comment --bvid <bvid> --text "学习了" --execute true --json

# trace
mediause trace last --json
```

Skill Metadata
Maintainer: @mediause-demo
Last-Updated: 2026-05-25
Version: v1
