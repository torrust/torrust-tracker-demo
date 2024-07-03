# Torrust Demo

This repo will contain all the configuration needed to run the live Torrust demo.

Live demo: <https://index.torrust-demo.com/torrents>.

It's also used to track issues in production.

## Setup

The application is located in the directory: `/home/torrust/github/torrust/torrust-compose/droplet`.

To run docker compose commands you need to cd to the app dir:

```console
cd github/torrust/torrust-compose/droplet/
```

Sample commands:

- `docker ps`: list containers.
- `docker compose logs -f`: print all containers' logs.
- `docker compose logs -f tracker`: print tracker container' logs.
- `docker compose logs -f tracker | head -n100`: print the first 100 lines in the tracker container log.
- `docker compose logs -f | grep "ERROR"`: print logs showing only errors.

## TODO

- Move configuration from <https://github.com/torrust/torrust-compose>.
- Create a workflow for deployments.
- Automatic deployment when new docker images are available.
- ...
