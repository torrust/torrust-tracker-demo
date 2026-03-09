# Issue Draft Format

A well-structured issue draft typically contains the sections below.
Not all sections are required for every issue — use what is relevant.

```markdown
# <Plain descriptive title>

**Issue**: #NNN _(to be filled in after opening the GitHub issue)_
**Related**: [other-repo#123](https://github.com/torrust/other-repo/issues/123)

## Overview

One or two paragraphs describing:

- What the problem or goal is
- Why it matters
- Any relevant background context

## <Investigation / Background / Specs>

Detailed sections relevant to the issue type:

- For bugs: symptoms, hypothesis, investigation steps, fix plan
- For features: requirements, design decisions, implementation plan
- For chores: what needs doing and why

## Implementation Plan

- [ ] Step 1
- [ ] Step 2
- [ ] Step 3

## Acceptance Criteria

- [ ] Criterion 1
- [ ] Criterion 2
```

## Notes

- Sections like "Implementation Plan" and "Acceptance Criteria" become GitHub task lists
  (checkboxes) and can be checked off as work progresses on the live issue.
- Keep secrets out of drafts. Use placeholder notation: `<SECRET_NAME>`.
- Link related issues and PRs using full URLs so they resolve correctly on GitHub.
