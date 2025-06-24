# Deployment

1. SSH into the server.
2. Execute the deployment script: `./bin/deploy-torrust-demo.com.sh`.
3. Execute the smoke tests:

    ```console
    # Clone Torrust Tracker
    git@github.com:torrust/torrust-tracker.git
    cd torrust-tracker
    ```

    Execute the following commands to run the tracker client and checker.

    Simulate a torrent announce to the tracker using UDP:

    ```console
    cargo run -p torrust-tracker-client --bin udp_tracker_client announce udp://tracker.torrust-demo.com:6969/announce 9c38422213e30bff212b30c360d26f9a02136422 | jq
    ```

    Simulate a torrent scrape to the tracker using HTTP:

    ```console
    cargo run -p torrust-tracker-client --bin http_tracker_client announce https://tracker.torrust-demo.com 9c38422213e30bff212b30c360d26f9a02136422 | jq
    ```

    Make a request to the health check endpoint:

    ```console
    TORRUST_CHECKER_CONFIG='{
        "udp_trackers": ["udp://tracker.torrust-demo.com:6969/announce"],
        "http_trackers": ["https://tracker.torrust-demo.com"],
        "health_checks": ["https://tracker.torrust-demo.com/api/health_check"]
    }' cargo run -p torrust-tracker-client --bin tracker_checker

    ```

4. Check the logs of the tracker container to see if everything is working:

    ```console
    ./share/bin/tracker-filtered-logs.sh
    ```
