# Torrust Demo

This repo contains all the configuration needed to run the live Torrust demo.

Live demo: <https://index.torrust-demo.com/torrents>.

It's also used to track issues in production.

## Setup

Follow instructions on [Deploying Torrust To Production](https://torrust.com/blog/deploying-torrust-to-production).

You need to also enable a [firewall](./docs/firewall.md).

The application is located in the directory: `/home/torrust/github/torrust/torrust-demo`.

To run docker compose commands you need to cd to the app dir:

```console
cd /home/torrust/github/torrust/torrust-demo
```

Sample commands:

- `docker ps`: list containers.
- `docker compose logs -f`: print all containers' logs.
- `docker compose logs -f tracker`: print tracker container' logs.
- `docker compose logs -f tracker | head -n100`: print the first 100 lines in the tracker container log.
- `docker compose logs -f | grep "ERROR"`: print logs showing only errors.

## Deployment

1. SSH into the server.
2. Execute the deployment script: `./bin/deploy-torrust-demo.com.sh`.
3. Execute the smoke tests:

    ```console
    cargo run --bin udp_tracker_client announce 144.126.245.19:6969 9c38422213e30bff212b30c360d26f9a02136422

    cargo run --bin http_tracker_client announce 144.126.245.19:6969 9c38422213e30bff212b30c360d26f9a02136422

    TORRUST_CHECKER_CONFIG='{
        "udp_trackers": ["144.126.245.19:6969"],
        "http_trackers": ["https://tracker.torrust-demo.com"],
        "health_checks": ["https://tracker.torrust-demo.com/api/health_check"]
    }' cargo run --bin tracker_checker
    ```

4. Check the logs of the tracker container to see if everything is working:

    ```console
    ./share/bin/tracker-filtered-logs.sh
    ```

## TODO

- Create a workflow for deployments.
- Automatic deployment when new docker images are available.
