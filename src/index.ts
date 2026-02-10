import { detectFocusedRepo } from "./detect"
import { getGitStatus, getLastCommit, getRemoteUrl, scanRepos } from "./git"
import type { GitBarOutput } from "./types"

function parseArgs() {
  const args = process.argv.slice(2)
  return {
    scan: args.includes("--scan"),
    scanDir: args.find((_, i, a) => a[i - 1] === "--scan-dir") || `${process.env.HOME}/Projects`,
  }
}

async function main() {
  const { scan, scanDir } = parseArgs()

  if (scan) {
    const repos = await scanRepos(scanDir)
    const output: GitBarOutput = { repos, timestamp: new Date().toISOString() }
    console.log(JSON.stringify(output))
    return
  }

  const detected = await detectFocusedRepo()

  if (!detected) {
    const output: GitBarOutput = { error: "not_a_repo", timestamp: new Date().toISOString() }
    console.log(JSON.stringify(output))
    return
  }

  const [status, lastCommit, remoteUrl] = await Promise.all([
    getGitStatus(detected.repoRoot),
    getLastCommit(detected.repoRoot),
    getRemoteUrl(detected.repoRoot),
  ])

  const output: GitBarOutput = {
    status,
    project_name: detected.projectName,
    project_path: detected.repoRoot,
    remote_url: remoteUrl ?? undefined,
    last_commit: lastCommit ?? undefined,
    timestamp: new Date().toISOString(),
  }

  console.log(JSON.stringify(output))
}

main()
