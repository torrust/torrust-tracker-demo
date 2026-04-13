---
name: create-issue-branch
description: Create a git branch to start working on a GitHub issue in the torrust-tracker-demo repository. Use when asked to start working on an issue, create a branch for an issue, or check out a new branch. Triggers on "create branch", "new branch", "start working on issue", "branch for issue", "checkout branch".
metadata:
  author: torrust
  version: "1.0"
---

# Creating a Branch for a GitHub Issue

## Branch Naming Convention

```text
<issue-number>-<issue-title-normalized>
```

**Rules**:

- Prefix with the GitHub issue number
- Follow with the issue title, lowercased, spaces replaced by hyphens
- Strip special characters (`:`, `/`, `(`, `)`, etc.)
- No type prefix (`feat/`, `fix/`, etc.)

**Examples**:

| Issue title                                         | Branch name                        |
| --------------------------------------------------- | ---------------------------------- |
| `feat: document and version-control server config`  | `1-document-server-configuration`  |
| `fix: UDP tracker down on newTrackon after restart` | `2-udp-tracker-down-on-newtrackon` |

## Workflow

### Step 1 — Confirm the issue number and title

Check the issue draft file (`docs/issues/ISSUE-<N>-*.md`) or the GitHub issue to get the
canonical title. Derive the normalized branch name from it.

### Step 2 — Present the branch name for approval

**Always show the branch name to the user and wait for explicit approval before creating it.**

### Step 3 — Create and switch to the branch locally

Create the branch locally only (do not push to remote at this stage):

```bash
git checkout -b <branch-name>
```

### Step 4 — Push to remote when creating the pull request

The branch is pushed to origin only when creating the pull request. Do not push the branch
to remote immediately after creation—wait until the PR workflow.
