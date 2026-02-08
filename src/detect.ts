import { readFile, readdir, readlink } from "fs/promises"
import { existsSync } from "fs"
import { dirname, join, basename } from "path"

const TERMINAL_APP_IDS = [
  "com.mitchellh.ghostty",
  "kitty",
  "alacritty",
  "foot",
  "org.wezfurlong.wezterm",
  "org.gnome.terminal",
  "com.raggesilver.blackbox",
]

interface NiriWindow {
  id: number
  app_id: string
  pid: number
  workspace_id: number
  is_focused: boolean
  focus_timestamp: { secs: number; nanos: number }
}

interface NiriWorkspace {
  id: number
  is_focused: boolean
}

function isTerminal(appId: string): boolean {
  return TERMINAL_APP_IDS.some((id) => appId.toLowerCase().includes(id.toLowerCase()))
}

async function getChildPids(pid: number): Promise<number[]> {
  const childPids: Set<number> = new Set()
  try {
    const threads = await readdir(`/proc/${pid}/task`).catch(() => [])
    for (const tid of threads) {
      const raw = await readFile(`/proc/${pid}/task/${tid}/children`, "utf-8").catch(() => "")
      for (const p of raw.trim().split(/\s+/).filter(Boolean)) {
        childPids.add(Number(p))
      }
    }
  } catch {}
  return [...childPids]
}

async function findLeafShellPid(pid: number, depth = 6): Promise<number | null> {
  if (depth <= 0) return null

  const childPids = await getChildPids(pid)
  for (const childPid of childPids) {
    try {
      const comm = (await readFile(`/proc/${childPid}/comm`, "utf-8")).trim()
      if (["bash", "zsh", "fish", "sh", "nu"].includes(comm)) {
        const deeper = await findLeafShellPid(childPid, depth - 1)
        return deeper ?? childPid
      }
      const deeper = await findLeafShellPid(childPid, depth - 1)
      if (deeper) return deeper
    } catch {}
  }
  return null
}

function findGitRoot(dir: string): string | null {
  let current = dir
  while (current !== "/") {
    if (existsSync(join(current, ".git"))) return current
    current = dirname(current)
  }
  return null
}

async function niriJson(args: string[]): Promise<any> {
  const proc = Bun.spawn(["niri", "msg", "--json", ...args], { stdout: "pipe", stderr: "pipe" })
  const output = await new Response(proc.stdout).text()
  const code = await proc.exited
  if (code !== 0 || !output.trim()) return null
  return JSON.parse(output)
}

async function repoFromPid(pid: number): Promise<{ repoRoot: string; projectName: string } | null> {
  const shellPid = await findLeafShellPid(pid)
  if (!shellPid) return null
  const cwd = await readlink(`/proc/${shellPid}/cwd`).catch(() => null)
  if (!cwd) return null
  const repoRoot = findGitRoot(cwd)
  if (!repoRoot) return null
  return { repoRoot, projectName: basename(repoRoot) }
}

export async function detectFocusedRepo(): Promise<{ repoRoot: string; projectName: string } | null> {
  try {
    // 1. Get focused workspace
    const workspaces = (await niriJson(["workspaces"])) as NiriWorkspace[] | null
    if (!workspaces) return null
    const focusedWs = workspaces.find((w) => w.is_focused)
    if (!focusedWs) return null

    // 2. Get all windows on this workspace
    const allWindows = (await niriJson(["windows"])) as NiriWindow[] | null
    if (!allWindows) return null

    const wsWindows = allWindows
      .filter((w) => w.workspace_id === focusedWs.id && isTerminal(w.app_id) && w.pid)
      .sort((a, b) => {
        // Most recently focused first
        const aTime = a.focus_timestamp.secs * 1e9 + a.focus_timestamp.nanos
        const bTime = b.focus_timestamp.secs * 1e9 + b.focus_timestamp.nanos
        return bTime - aTime
      })

    // 3. Try each terminal (most recently focused first) until we find a git repo
    for (const win of wsWindows) {
      const result = await repoFromPid(win.pid)
      if (result) return result
    }

    return null
  } catch {
    return null
  }
}
