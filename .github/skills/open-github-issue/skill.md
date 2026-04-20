---
name: open-github-issue
description: Step-by-step process for creating and opening a GitHub issue in the torrust-tracker-demo repository. Use when asked to open, create, or file an issue. Covers writing the draft file, human review, opening on GitHub, renaming the file, and committing. Triggers on "open issue", "create issue", "new issue", "file issue", "draft issue".
metadata:
  author: torrust
  version: "1.2"
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

- Always use a non-numbered draft path before publication:
  `docs/issues/drafts/short-description.md`
- Do **not** create `docs/issues/ISSUE-<number>-...` before the GitHub issue exists.

> **Important**: never guess or assume the issue number. The real number is only known
> after Step 4 (opening the issue on GitHub). Before Step 4:
>
> - Keep the draft in `docs/issues/drafts/`.
> - Use `**Issue**: _(to be filled after publication)_`.
> - Never write guessed links such as `[#14](...)` in draft content.

**Draft file structure** (use Markdown, no fixed template required):

```markdown
# <Title>

**Issue**: _(to be filled after publication)_
**Related**: <links to related issues in this or other repos — omit this line entirely if there are none>

## Overview

<Why this issue exists and what it aims to achieve>

## <Relevant sections>

<Investigation, specs, acceptance criteria, implementation plan, etc.>
```

**Title convention**: plain descriptive title, not prefixed with conventional commit type.

### Step 2 — Run linters

Use the canonical lint script (see the `run-linters` skill for prerequisites and troubleshooting):

```bash
./scripts/lint.sh
```

Fix any errors. Add new project-specific words to `project-words.txt` (one word per line, keep the
file sorted). Re-run the linter after editing `project-words.txt` to confirm the errors are gone.

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
  `**Related**:` can be kept or adapted for GitHub)
- Note the assigned issue number from the response.
- If opening is canceled or fails, do not invent a number and do not rename the draft file.

> **Multiple issues in one session**: when one issue will reference another (e.g. a follow-up
> issue that links back to a root cause issue), open them in dependency order — open the
> referenced issue first, record its number, then open the referencing issue with the real link.
> Never guess or placeholder the number of an issue that has not been opened yet.

### Step 5 — Rename the draft file and update the issue link

```bash
# Move draft to canonical path only after GitHub assigns the number
mv docs/issues/drafts/short-description.md docs/issues/ISSUE-<N>-short-description.md
```

Update the `**Issue**:` line inside the file to a full link, and update `**Related**:` if it
contains placeholder text:

```markdown
**Issue**: [#<N>](https://github.com/torrust/torrust-tracker-demo/issues/<N>)
```

### Step 6 — Lint again, then commit and push

```bash
./scripts/lint.sh
```

```bash
# Stage the issue file; also stage project-words.txt if new words were added
git add docs/issues/ISSUE-<N>-short-description.md
git add project-words.txt   # only if modified
git commit -m "docs: add issue file for <short description>

Refs: #<N>"
git push
```

## Draft Location Decision

| Situation                                   | Location                                     |
| ------------------------------------------- | -------------------------------------------- |
| Any issue before publication                | `docs/issues/drafts/short-description.md`    |
| Published issue (number assigned by GitHub) | `docs/issues/ISSUE-<N>-short-description.md` |

> Feature specifications and design documents are a separate process not yet defined for this
> project.

## Reference

See [issue-draft-format.md](references/issue-draft-format.md) for a fuller example of a
well-structured draft.
