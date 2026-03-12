# Add Legal Disclaimer to Protect the Torrust Org and Contributors

**Issue**: [#11](https://github.com/torrust/torrust-tracker-demo/issues/11)
**Related**:
[torrust/torrust-index-gui](https://github.com/torrust/torrust-index-gui) —
contains a similar disclaimer that can serve as a starting point.

## Overview

The Torrust Tracker Demo runs a publicly accessible BitTorrent tracker. While
its purpose is purely educational — to demonstrate how to deploy and operate
the [Torrust Tracker](https://github.com/torrust/torrust-tracker) — the tracker
endpoints are reachable from the internet and can be used by anyone.

BitTorrent trackers are a known target for legal actions in some jurisdictions,
because they can be used to coordinate the distribution of infringing content.
The Torrust Org and its contributors are not responsible for the content tracked
by the demo, and the demo is not intended to facilitate any illegal activity.
However, without an explicit disclaimer, this intent is not clear to users or
to third parties.

This issue tracks the work needed to add a legal disclaimer that:

- Makes clear that the demo is for documentation and educational purposes only.
- States that users are responsible for their own use of the tracker.
- States that the Torrust Org and contributors are not liable for misuse.
- Informs users that tracker data may be periodically reset.

A follow-up issue should be opened to have the final disclaimer text reviewed
by a legal professional before the project reaches a larger audience.

## Proposed Disclaimer Text

The following text is proposed as an immediate first version, modelled on the
disclaimer already in use in the
[torrust/torrust-index-gui](https://github.com/torrust/torrust-index-gui)
repository:

---

### Disclaimer

This demo tracker is provided **for documentation and educational purposes
only**. It is intended to demonstrate how to deploy and operate the
[Torrust Tracker](https://github.com/torrust/torrust-tracker), and not to
provide a persistent or general-purpose public tracking service.

This software is provided solely for lawful purposes. Users must ensure
compliance with all applicable laws and regulations regarding copyright and
intellectual property. The Torrust organization and its contributors do not
condone or support the use of this tracker for any illegal activities, including
but not limited to the distribution of copyrighted, protected, or otherwise
illegal content.

By using this tracker, you agree to use it responsibly and in compliance with
all applicable legal requirements. Misuse of this tracker for illegal purposes
may lead to legal consequences, for which the Torrust organization and its
contributors are not liable.

**Tracker data (peer lists, announce history) may be reset at any time without
notice.**

---

## Implementation Plan

- [ ] Add the disclaimer as a `## Disclaimer` section to `README.md`.
- [ ] Add the disclaimer text to `project-words.txt` for any technical terms
      that fail the spell checker.
- [ ] Open a follow-up issue to have the final text reviewed by a legal
      professional.

## Acceptance Criteria

- [ ] `README.md` contains a visible `## Disclaimer` section with the agreed
      text.
- [ ] The repository passes the markdown linter (`npx markdownlint-cli2
"**/*.md"`).
- [ ] The repository passes the spell checker (`npx cspell --no-progress`).
- [ ] A follow-up issue for legal review is referenced or opened.
