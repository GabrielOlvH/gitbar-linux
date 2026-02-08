export interface GitStatus {
  branch: string
  dirty: boolean
  staged: number
  unstaged: number
  untracked: number
  ahead: number
  behind: number
}

export interface LastCommit {
  hash: string
  message: string
  time_ago: string
}

export interface RepoSummary {
  name: string
  path: string
  branch: string
  dirty: boolean
  ahead: number
  behind: number
  last_commit_ago: string
}

export interface GitBarOutput {
  status?: GitStatus
  project_name?: string
  project_path?: string
  last_commit?: LastCommit
  repos?: RepoSummary[]
  error?: string
  timestamp: string
}
