---
name: open-pull-request
description: Create and open a pull request in the torrust-tracker-demo repository. Use when asked to open a PR, create a pull request, submit a PR, or push changes and create a PR. Triggers on "open PR", "create PR", "submit PR", "push and open PR", "open pull request".
metadata:
  author: torrust
  version: "1.0"
---

# Opening a Pull Request

This skill guides you through pushing your branch and creating a pull request on GitHub.

## Prerequisites

- Local commits already created and ready to push
- Branch created locally (see `create-issue-branch` skill for branch creation)
- GitHub CLI installed and authenticated

## Workflow

### Step 1 — Push the branch to remote

Push the local branch to the remote repository:

```bash
git push -u origin <branch-name>
```

The `-u` flag sets the upstream tracking branch. Git will output a link to create a PR.

### Step 2 — Prepare the PR title and description

**Title**: Follow Conventional Commits format with the issue type and scope

**Examples**:

- `feat(docker): update Docker images for security vulnerability fixes`
- `fix(tracker): resolve UDP socket binding issue`
- `docs: update deployment guide`

**Description**: Should include:

- Brief summary of the change
- Context or motivation (reference related issues or PRs)
- Changes made (list key files or components modified)
- Verification checklist (if applicable)
- Link to related issue using `Fixes #<issue-number>` or `Refs: #<issue-number>`

### Step 3 — Create the pull request

Use GitHub CLI to create the PR with title and description:

```bash
gh pr create \
  --title "feat(scope): description" \
  --body "Description with Fixes #<issue-number>" \
  --base main \
  --head <branch-name>
```

The `--body` parameter supports markdown. Use `Fixes #<issue-number>` to auto-link and auto-close the issue when merged.

### Step 4 — Verify the PR was created

GitHub CLI will output the PR URL:

```text
https://github.com/torrust/torrust-tracker-demo/pull/<number>
```

Open it to:

- Review the commits
- Verify the issue is linked
- Check that CI/CD checks pass
- Monitor for review comments

## Tips

- **Link to issues**: Always include `Fixes #<issue-number>` in the PR body to auto-link
- **Review before pushing**: Run `git log --oneline -n <count>` to verify commits are correct
- **Check branch status**: Verify you're on the correct branch with `git status` before pushing
- **Wait for checks**: GitHub Actions will run linters and tests. Wait for them to pass before merging.

## Related Skills

- `create-issue-branch` — Creating a new branch for an issue
- `commit` — Committing changes to the repository
