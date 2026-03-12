---
name: open-github-issue
description: Step-by-step process for creating and opening a GitHub issue in the torrust-tracker-demo repository. Use when asked to open, create, or file an issue. Covers writing the draft file, human review, opening on GitHub, renaming the file, and committing. Triggers on "open issue", "create issue", "new issue", "file issue", "draft issue".
metadata:
  author: torrust
  version: "1.0"
---

# Opening a GitHub Issue

## Overview

All issues follow a **draft-first** workflow: write and review locally before opening on GitHub.
This ensures human review before any public issue is filed and keeps a permanent record of the
issue spec in the repository.

## Workflow

### Step 1 — Write the draft file

Create the draft under `docs/issues/` using the naming conventions below.

**File naming**:

- Ready to open soon: `docs/issues/ISSUE-NNN-short-description.md` (use `NNN` as placeholder)
- Long-running or complex: `docs/issues/drafts/short-description.md` (no issue number prefix)

> **Important**: never guess or assume the issue number. The real number is only known
> after Step 4 (opening the issue on GitHub). Always use literal `NNN` in both the
> filename and the `**Issue**:` line until the GitHub API returns the assigned number.

**Draft file structure** (use Markdown, no fixed template required):

```markdown
# <Title>

**Issue**: #NNN _(to be filled in after opening the GitHub issue)_
**Related**: <links to related issues in this or other repos, if any>

## Overview

<Why this issue exists and what it aims to achieve>

## <Relevant sections>

<Investigation, specs, acceptance criteria, implementation plan, etc.>
```

**Title convention**: plain descriptive title, not prefixed with conventional commit type.

### Step 2 — Run linters

```bash
npx markdownlint-cli2 "**/*.md"
npx cspell --no-progress
```

Fix any errors. Add new project-specific words to `project-words.txt` (one word per line).

### Step 3 — Human review

**Do not open the GitHub issue or commit the draft until the human has reviewed and approved.**
Present the draft content and wait for explicit approval.

### Step 4 — Open the GitHub issue

Use the GitHub API/tool to create the issue:

- **Title**: must follow Conventional Commits format — `<type>[scope]: <description>`
  - `feat:` new features or configuration
  - `fix:` bug fixes
  - `docs:` documentation
  - `chore:` maintenance
- **Body**: paste the draft content, omitting the frontmatter lines (`**Issue**: #NNN` and
  `**Related**:` can be kept or adapted for GitHub; the `#NNN` marker should be updated to the
  real issue number)
- Note the assigned issue number from the response

### Step 5 — Rename the draft file and update the issue link

```bash
# Rename: replace NNN with the real issue number
mv docs/issues/ISSUE-NNN-short-description.md docs/issues/ISSUE-<N>-short-description.md
```

Update the `**Issue**: #NNN` line inside the file to a full link:

```markdown
**Issue**: [#<N>](https://github.com/torrust/torrust-tracker-demo/issues/<N>)
```

If the draft was in `docs/issues/drafts/`, move it to `docs/issues/ISSUE-<N>-short-description.md`.

### Step 6 — Lint again, then commit and push

```bash
npx markdownlint-cli2 "**/*.md"
npx cspell --no-progress
```

```bash
git add docs/issues/ISSUE-<N>-short-description.md
git commit -m "docs: add draft issue for <short description>

Refs: #<N>"
git push
```

**Note**: if the `ISSUE-NNN-` file was previously committed (tracked by git), also stage its
deletion so git does not report it as an uncommitted change:

```bash
git rm docs/issues/ISSUE-NNN-short-description.md
```

## Draft Location Decision

| Situation                                 | Location                                     |
| ----------------------------------------- | -------------------------------------------- |
| Simple issue, will be worked on soon      | `docs/issues/ISSUE-NNN-short-description.md` |
| Complex / long-term / needs more research | `docs/issues/drafts/short-description.md`    |

> Feature specifications and design documents are a separate process not yet defined for this
> project.

## Reference

See [issue-draft-format.md](references/issue-draft-format.md) for a fuller example of a
well-structured draft.
