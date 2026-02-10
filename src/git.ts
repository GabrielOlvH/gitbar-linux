import { readdir } from "fs/promises"
import { existsSync } from "fs"
import { join, basename, relative, dirname } from "path"
import type { GitStatus, LastCommit, RepoSummary } from "./types"

async function run(args: string[], cwd: string): Promise<string> {
  const proc = Bun.spawn(args, { stdout: "pipe", stderr: "pipe", cwd })
  const stdout = await new Response(proc.stdout).text()
  await proc.exited
  return stdout.trim()
}

export async function getGitStatus(repoRoot: string): Promise<GitStatus> {
  const [branch, porcelain, upstreamRaw] = await Promise.all([
    run(["git", "branch", "--show-current"], repoRoot),
    run(["git", "status", "--porcelain=v1"], repoRoot),
    run(["git", "rev-list", "--left-right", "--count", "@{u}...HEAD"], repoRoot).catch(() => "0\t0"),
  ])

  let staged = 0
  let unstaged = 0
  let untracked = 0

  for (const line of porcelain.split("\n")) {
    if (!line) continue
    const x = line[0]
    const y = line[1]
    if (x === "?" && y === "?") {
      untracked++
    } else {
      if (x !== " " && x !== "?") staged++
      if (y !== " " && y !== "?") unstaged++
    }
  }

  const [behind, ahead] = upstreamRaw.split(/\s+/).map(Number)

  return {
    branch: branch || "HEAD",
    dirty: staged + unstaged + untracked > 0,
    staged,
    unstaged,
    untracked,
    ahead: ahead || 0,
    behind: behind || 0,
  }
}

export async function getRemoteUrl(repoRoot: string): Promise<string | null> {
  try {
    const url = await run(["git", "remote", "get-url", "origin"], repoRoot)
    if (!url) return null
    // Convert SSH URLs to HTTPS: git@github.com:user/repo.git → https://github.com/user/repo
    const sshMatch = url.match(/^git@([^:]+):(.+?)(?:\.git)?$/)
    if (sshMatch) return `https://${sshMatch[1]}/${sshMatch[2]}`
    return url.replace(/\.git$/, "")
  } catch {
    return null
  }
}

export async function getLastCommit(repoRoot: string): Promise<LastCommit | null> {
  try {
    const raw = await run(["git", "log", "-1", "--format=%H%n%s%n%cr"], repoRoot)
    const lines = raw.split("\n")
    if (lines.length < 3) return null
    return {
      hash: lines[0].slice(0, 7),
      message: lines[1],
      time_ago: lines[2],
    }
  } catch {
    return null
  }
}

async function findGitRepos(dir: string, depth = 2): Promise<string[]> {
  if (depth <= 0) return []
  const repos: string[] = []
  try {
    const entries = await readdir(dir, { withFileTypes: true })
    for (const entry of entries) {
      if (!entry.isDirectory() || entry.name.startsWith(".") || entry.name === "node_modules") continue
      const full = join(dir, entry.name)
      if (existsSync(join(full, ".git"))) {
        repos.push(full)
      } else {
        repos.push(...await findGitRepos(full, depth - 1))
      }
    }
  } catch {}
  return repos
}

export async function scanRepos(projectsDir: string): Promise<RepoSummary[]> {
  const repoPaths = await findGitRepos(projectsDir)
  const results = await Promise.allSettled(
    repoPaths.map(async (repoPath): Promise<RepoSummary> => {
      const [status, commitRaw, remoteUrl] = await Promise.all([
        getGitStatus(repoPath),
        run(["git", "log", "-1", "--format=%cr"], repoPath).catch(() => ""),
        getRemoteUrl(repoPath),
      ])
      const rel = relative(projectsDir, repoPath)
      const parent = dirname(rel)
      return {
        name: basename(repoPath),
        path: repoPath,
        group: parent === "." ? "" : parent,
        branch: status.branch,
        dirty: status.dirty,
        ahead: status.ahead,
        behind: status.behind,
        last_commit_ago: commitRaw,
        remote_url: remoteUrl || "",
      }
    }),
  )
  return results
    .filter((r): r is PromiseFulfilledResult<RepoSummary> => r.status === "fulfilled")
    .map((r) => r.value)
    .sort((a, b) => a.group.localeCompare(b.group) || a.name.localeCompare(b.name))
}
