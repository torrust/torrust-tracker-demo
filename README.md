# Torrust Tracker Demo

This repository contains the configuration needed to run the live
[Torrust Tracker](https://github.com/torrust/torrust-tracker) demo.

Live demo tracker endpoints:

- HTTP: <https://http1.torrust-tracker-demo.com:443/announce>
- UDP: `udp://udp1.torrust-tracker-demo.com:6969/announce`

> The tracker is listed on [newtrackon](https://newtrackon.com/) for public uptime tracking.

## Background

[Torrust](https://github.com/torrust) is an open-source organization building
BitTorrent tools in Rust. Our two main projects are:

- **[Torrust Tracker](https://github.com/torrust/torrust-tracker)** — a
  feature-complete BitTorrent tracker (UDP + HTTP, IPv4 + IPv6).
- **[Torrust Index](https://github.com/torrust/torrust-index)** — a BitTorrent
  index (think: a self-hosted torrent site). It integrates with the tracker to
  automatically embed the tracker URL into uploaded torrents.

We have been running a combined live demo of both services since **April 24,
2024**, available at <https://index.torrust-demo.com>. That demo serves as a
reference deployment and a public integration test for the two applications
working together.

### Why this repo exists

The original demo lived in a single repository:
[torrust/torrust-demo](https://github.com/torrust/torrust-demo).

After running the combined demo for a while, we decided to split it into two
separate repositories
([torrust-demo#79](https://github.com/torrust/torrust-demo/issues/79)):

- **[torrust/torrust-tracker-demo](https://github.com/torrust/torrust-tracker-demo)**
  — this repository (tracker only).
- **torrust/torrust-index-demo** — the index demo (coming soon).

Reasons for the split:

- **Independent deployability** — the tracker and index can be deployed,
  updated, and scaled separately.
- **Independent teams** — different maintainers can own each demo without
  stepping on each other.
- **Independent scaling** — tracker and index have very different traffic
  patterns and resource needs.
- **Tracker-only users** — many users only need a tracker. Keeping tracker
  configuration separate makes it easier to adopt.

## Purpose of this repository

- **Share the demo configuration** — so that others can replicate the setup
  for their own deployments.
- **Track production issues** — issues raised here correspond to problems or
  improvements observed in the live demo environment.
- **Document deployment** — we believe there is a significant lack of
  practical documentation on how to deploy and operate BitTorrent tools. This
  repo is part of our effort to fix that.

## Demo details

| Property      | Value                                                                 |
| ------------- | --------------------------------------------------------------------- |
| Running since | March 3, 2026                                                         |
| Database      | MySQL                                                                 |
| IP support    | IPv4 + IPv6                                                           |
| Hosting       | [Hetzner](https://www.hetzner.com/)                                   |
| Monitoring    | Grafana (dashboards for peer connections, performance, system health) |

The new tracker uses **MySQL** (the original combined demo used SQLite) and
supports both **IPv4 and IPv6**.

The server was provisioned using
[torrust-tracker-deployer](https://github.com/torrust/torrust-tracker-deployer).

## Related projects

| Repository                                                                              | Description                                    |
| --------------------------------------------------------------------------------------- | ---------------------------------------------- |
| [torrust/torrust-tracker](https://github.com/torrust/torrust-tracker)                   | The tracker software itself                    |
| [torrust/torrust-index](https://github.com/torrust/torrust-index)                       | The index software                             |
| [torrust/torrust-demo](https://github.com/torrust/torrust-demo)                         | Original combined demo (Index + Tracker)       |
| [torrust/torrust-tracker-deployer](https://github.com/torrust/torrust-tracker-deployer) | Deployment tooling used to provision this demo |

## Contributing

Feedback, issues, and pull requests are welcome. If you spot a problem with the
live demo or have a suggestion for improving the configuration or documentation,
please [open an issue](https://github.com/torrust/torrust-tracker-demo/issues).
