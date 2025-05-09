# Deployment

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
