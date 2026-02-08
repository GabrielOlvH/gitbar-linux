# GitBar

Git branch and status monitor for [DankMaterialShell](https://github.com/nicko-coder/DankMaterialShell) (DMS/niri).

![Bun](https://img.shields.io/badge/runtime-Bun-f9f1e1?logo=bun)
![TypeScript](https://img.shields.io/badge/lang-TypeScript-3178c6?logo=typescript&logoColor=white)

## What it does

- Detects the git repo from any terminal on the **current workspace** (not just the focused window)
- Shows branch name, dirty state, ahead/behind, staged/unstaged/untracked counts
- Scans all repos under `~/Projects` for a project overview
- Uses niri IPC + `/proc` tree walking for terminal detection

## Pill

`commit` icon + branch name (truncated) + dirty dot (green = clean, yellow = dirty). Shows ahead/behind counts when present. Always visible — shows just the icon when no repo is detected.

## Popout

When in a repo: project name, branch with dirty/clean badge, status breakdown (staged/unstaged/untracked), last commit info.

Always: scrollable list of all repos found under `~/Projects` with branch, dirty state, and last commit time.

## Setup

```bash
bun install
```

### CLI

```bash
# Detect focused workspace terminal → git repo
bun run src/index.ts

# Scan all repos under ~/Projects
bun run src/index.ts --scan

# Scan a custom directory
bun run src/index.ts --scan --scan-dir /path/to/projects
```

### DMS Plugin

Copy `plugin/` to `~/.config/DankMaterialShell/plugins/GitBar/` and add the widget to your bar.

## How detection works

1. Gets the focused workspace via `niri msg --json workspaces`
2. Finds all terminal windows on that workspace via `niri msg --json windows`
3. Sorts by most recently focused
4. Walks `/proc/{pid}/task/*/children` to find the leaf shell process
5. Reads `/proc/{shellPid}/cwd` to get the working directory
6. Walks up to find the `.git` root

This means GitBar shows the correct repo even when you're focused on a browser or other app, as long as there's a terminal on the same workspace.

## Architecture

Bun TypeScript backend outputs JSON to stdout, consumed by the QML plugin via `Proc.runCommand`.
