# Deployment

This document outlines the deployment process for the Torrust Tracker demo application.

## 1. Prerequisites

- Ensure you have SSH access to the production server.
- The server should be provisioned and configured according to the
  [Production Setup Guide](./production-setup.md).

## 2. Deployment Steps

The Torrust Tracker Demo now uses a **twelve-factor app deployment workflow**
that separates infrastructure provisioning from application deployment.

### From Local Machine (Recommended)

Use the automated deployment workflow from your local development machine:

```bash
# Deploy infrastructure and application (complete workflow)
make infra-apply ENVIRONMENT=production
make app-deploy ENVIRONMENT=production

# Validate deployment
make app-health-check ENVIRONMENT=production
```

### Manual Deployment on Server (Legacy)

If you need to manually deploy on the server:

1. **SSH into the server**.

2. **Navigate to the application directory**:

   ```bash
   cd /home/torrust/github/torrust/torrust-tracker-demo/application
   ```

3. **Pull the latest changes** from the repository:

   ```bash
   git pull
   ```

4. **Deploy using Docker Compose**:

   ```bash
   # Use the persistent volume environment file
   docker compose --env-file /var/lib/torrust/compose/.env pull
   docker compose --env-file /var/lib/torrust/compose/.env down
   docker compose --env-file /var/lib/torrust/compose/.env up -d
   ```

## 3. SSL Certificate Management

### Certificate Generation Strategy

The deployment process generates SSL certificates on each deployment rather than
reusing certificates. This approach provides several advantages:

#### Why Generate Certificates Per Deployment?

1. **Production Flexibility**: Different environments use different domains:

   - Local testing: `test.local`
   - Staging: `staging.example.com`
   - Production: `tracker.torrust-demo.com`

2. **Certificate Validity**: Self-signed certificates are domain-specific and must
   exactly match the domain being used in each deployment environment.

3. **Security Best Practices**: Fresh certificates for each deployment ensure no
   stale or leaked credentials are reused.

4. **Workflow Consistency**: The same deployment process works across all
   environments without manual certificate management or copying certificates
   between systems.

5. **Zero Configuration**: No need to maintain a certificate store or handle
   certificate distribution between development and production environments.

#### Certificate Types by Environment

- **Local/Testing**: Self-signed certificates with 10-year validity (for convenience in testing)
- **Production**: Let's Encrypt certificates (automatically renewed)

#### Implementation Details

The certificate generation happens during the application deployment phase
(`make app-deploy`) and includes:

1. **Self-signed certificates**: Generated using OpenSSL with domain-specific
   Subject Alternative Names (SAN)
2. **Certificate placement**: Stored in `/var/lib/torrust/proxy/certs/` and
   `/var/lib/torrust/proxy/private/` on the target server
3. **Container mounting**: Certificates are mounted into nginx container at runtime
4. **Automatic configuration**: nginx configuration is automatically templated
   with the correct certificate paths

While it would be possible to reuse certificates for local testing (since we
always use `test.local`), this approach ensures that the deployment workflow is
identical between local testing and production, reducing the chance of
environment-specific issues.

## 4. Verification and Smoke Testing

After deployment, verify that all services are running correctly.

### Service Status

Check the status of all Docker containers:

```bash
# From local machine
make app-health-check ENVIRONMENT=production

# Or manually on server
cd /home/torrust/github/torrust/torrust-tracker-demo/application
docker compose --env-file /var/lib/torrust/compose/.env ps
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
