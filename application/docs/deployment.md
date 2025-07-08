# Deployment

This document outlines the deployment process for the Torrust Tracker demo application.

## 1. Prerequisites

- Ensure you have SSH access to the production server.
- The server should be provisioned and configured according to the [Production Setup Guide](./production-setup.md).

## 2. Deployment Steps

1. **SSH into the server**.

2. **Navigate to the application directory**:

   ```bash
   cd /home/torrust/github/torrust/torrust-tracker-demo
   ```

3. **Pull the latest changes** from the repository:

   ```bash
   git pull
   ```

4. **Run the deployment script**:

   ```bash
   ./share/bin/deploy-torrust-tracker-demo.com.sh
   ```

   This script handles:

   - Stopping services
   - Rebuilding containers
   - Starting services

## 3. Verification and Smoke Testing

After deployment, verify that all services are running correctly.

### Service Status

Check the status of all Docker containers:

```bash
docker compose ps
```

### Application Logs

Check the logs for the tracker container to ensure it started without errors:

```bash
./share/bin/tracker-filtered-logs.sh
```

### Smoke Tests

Execute the following smoke tests from a machine with the `torrust-tracker` repository cloned.

1. **UDP Announce**:

   ```bash
   cargo run -p torrust-tracker-client --bin udp_tracker_client announce \
     udp://tracker.torrust-demo.com:6969/announce \
     9c38422213e30bff212b30c360d26f9a02136422 | jq
   ```

2. **HTTP Announce**:

   ```bash
   cargo run -p torrust-tracker-client --bin http_tracker_client announce \
     https://tracker.torrust-demo.com/announce \
     9c38422213e30bff212b30c360d26f9a02136422 | jq
   ```

3. **Health Check Endpoint**:

   ```bash
   curl https://tracker.torrust-demo.com/api/health_check
   ```

4. **Run the comprehensive tracker checker**:

   ```bash
   TORRUST_CHECKER_CONFIG='{
       "udp_trackers": ["udp://tracker.torrust-demo.com:6969/announce"],
       "http_trackers": ["https://tracker.torrust-demo.com/announce"],
       "health_checks": ["https://tracker.torrust-demo.com/api/health_check"]
   }' cargo run -p torrust-tracker-client --bin tracker_checker
   ```
