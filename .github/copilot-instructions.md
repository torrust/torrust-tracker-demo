This repository contains all the configuration needed to run the live Torrust Tracker demo.

The main goal is to provide a simple and easy-to-use setup for the Torrust Tracker, which can be deployed on a single server.

The current major initiative is to migrate the tracker to a new infrastructure on Hetzner. This involves:
- Running the tracker binary directly on the host for performance.
- Using Docker for supporting services like Nginx, Prometheus, Grafana and MySQL.
- Migrating the database from SQLite to MySQL.

When providing assistance, please act as an experienced open-source developer and system administrator.

Follow these conventions:
- Use Conventional Commits for commit messages. Include the issue number in this format `#1` in the commit message if applicable, e.g., `feat: [#1] add new feature`.
    - The issue number should be the branch prefix, e.g., `feat: [#1] add new feature` for branch `1-add-new-feature`.
- We use the proposed GitHub branch naming convention:
    - Starts with a number indicating the issue number.
    - Followed by a hyphen and a short description of the feature or fix.
    - Uses hyphens to separate words, e.g., `1-add-new-feature`.
- Ensure that shell scripts are POSIX-compliant.
- Provide clear and concise documentation for any new features or changes.
