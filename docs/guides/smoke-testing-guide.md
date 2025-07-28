# Smoke Testing Guide

This guide explains how to run end-to-end smoke tests against a deployed
Torrust Tracker using official client tools. This is perfect for quick
validation after deployment or when you want to verify functionality without
needing to understand the infrastructure internals.

## Overview

Smoke testing provides:

- ✅ **Quick validation** (~5 minutes)
- ✅ **External black-box testing** using official Torrust client tools
- ✅ **Protocol-level verification** (UDP, HTTP, API endpoints)
- ✅ **No infrastructure knowledge required**
- ✅ **Perfect for post-deployment validation**

This approach complements the [Integration Testing Guide](integration-testing-guide.md)
by providing a simpler alternative when you only need to verify that the
deployed tracker is working correctly.

## Prerequisites

### System Requirements

- Git installed
- Rust toolchain (cargo) installed
- Network access to the deployed Torrust Tracker

### Target Environment

This guide covers testing against:

- **Local/Demo Environment**: HTTP without certificates (development)
- **Future Scope**: Production environments with Let's Encrypt certificates

> **Note**: Certificate generation with Let's Encrypt for HTTP services
> (Tracker API on port 1212, HTTP tracker on port 7070, Grafana, etc.)
> is not fully automated yet. This guide currently focuses on local
> testing environments.

## Step 1: Setup Torrust Tracker Client

### 1.1 Get the Torrust Tracker Repository

You have two options for accessing the Torrust Tracker client tools:

#### Option A: Use Existing Installation

If you already have the Torrust Tracker repository cloned:

```bash
# Navigate to your existing torrust-tracker directory
cd /path/to/your/torrust-tracker
# Example: cd /home/josecelano/Documents/git/committer/me/github/torrust/torrust-tracker

# Verify you have the client tools
ls -la src/bin/ | grep -E "(udp_tracker_client|http_tracker_client|tracker_checker)"
```

#### Option B: Clone Fresh Copy

If you don't have the repository, clone it locally:

```bash
# Clone the official Torrust Tracker repository
git clone https://github.com/torrust/torrust-tracker
cd torrust-tracker
```

> **Note**: If cloning locally, the `torrust-tracker/` directory is already
> added to `.gitignore` to avoid conflicts with the demo repository.

### 1.2 Verify Rust Installation

```bash
# Check Rust version (required for compiling client tools)
cargo --version
rustc --version

# If Rust is not installed, install it:
# curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
# source ~/.cargo/env
```

### 1.3 Understanding Client Tools

> **Important**: The Torrust Tracker client tools are **not published on
> crates.io** yet. They must be compiled from source using the tracker
> repository. You cannot install them with `cargo install` - you must
> run them using `cargo run` from the tracker root directory.

The available client tools are:

- `udp_tracker_client` - Tests UDP tracker protocol
- `http_tracker_client` - Tests HTTP tracker protocol
- `tracker_checker` - Comprehensive health checker

### 1.4 Verify Client Tools

```bash
# Verify you're in the tracker root directory
pwd
ls Cargo.toml

# Check available client binaries
ls -la src/bin/ | grep -E "client|checker"

# Test that client tools can be run (will show help/usage)
cargo run -p torrust-tracker-client --bin udp_tracker_client -- --help
cargo run -p torrust-tracker-client --bin http_tracker_client -- --help
cargo run -p torrust-tracker-client --bin tracker_checker -- --help
```

## Step 2: Identify Target Server

### 2.1 For Local VM Testing

If you're testing against a local VM deployed with the integration guide:

```bash
# Get VM IP address (if using local VM)
VM_IP=$(cd infrastructure/terraform && tofu output -raw vm_ip 2>/dev/null) || \
VM_IP=$(virsh domifaddr torrust-tracker-demo | grep ipv4 | awk '{print $4}' | cut -d'/' -f1)

echo "Testing against VM: $VM_IP"
```

### 2.2 For Remote Server Testing

```bash
# Set your target server IP or domain
TARGET_SERVER="your-server.example.com"
# or
TARGET_SERVER="192.168.1.100"

echo "Testing against server: $TARGET_SERVER"
```

### 2.3 Verify Server Accessibility

```bash
# Test basic connectivity
ping -c 3 $TARGET_SERVER

# Test if tracker ports are open
nc -zv $TARGET_SERVER 6868  # UDP tracker port 1
nc -zv $TARGET_SERVER 6969  # UDP tracker port 2
nc -zv $TARGET_SERVER 7070  # HTTP tracker port
nc -zv $TARGET_SERVER 1212  # API/metrics port
```

## Step 3: Run Smoke Tests

### 3.1 Test UDP Trackers

#### UDP Tracker on Port 6868

```bash
# Test UDP tracker on port 6868
echo "=== Testing UDP Tracker (6868) ==="
cargo run -p torrust-tracker-client --bin udp_tracker_client announce \
  udp://$TARGET_SERVER:6868/announce \
  9c38422213e30bff212b30c360d26f9a02136422 | jq
```

**Expected Output:**

```json
{
  "transaction_id": 2425393296,
  "announce_response": {
    "interval": 120,
    "leechers": 0,
    "seeders": 0,
    "peers": []
  }
}
```

#### UDP Tracker on Port 6969

```bash
# Test UDP tracker on port 6969
echo "=== Testing UDP Tracker (6969) ==="
cargo run -p torrust-tracker-client --bin udp_tracker_client announce \
  udp://$TARGET_SERVER:6969/announce \
  9c38422213e30bff212b30c360d26f9a02136422 | jq
```

**Expected Output:** Similar JSON response with tracker statistics.

### 3.2 Test HTTP Tracker

#### Through Nginx Proxy (Port 80) - ✅ Working

The HTTP tracker is configured to run behind an nginx reverse proxy. The nginx
configuration now properly passes the `X-Forwarded-For` header, enabling HTTP
tracker functionality through the proxy:

```bash
# Test HTTP tracker through nginx proxy on port 80
echo "=== Testing HTTP Tracker through Nginx Proxy (80) ==="
cargo run -p torrust-tracker-client --bin http_tracker_client announce \
  http://$TARGET_SERVER:80 \
  9c38422213e30bff212b30c360d26f9a02136422 | jq
```

**Expected Output:**

```json
{
  "complete": 1,
  "incomplete": 0,
  "interval": 300,
  "min interval": 300,
  "peers": [
    {
      "ip": "192.168.122.1",
      "peer id": [
        45, 113, 66, 48, 48, 48, 48, 48, 48, 48, 48, 48, 48, 48, 48, 48, 48, 48,
        48, 49
      ],
      "port": 47401
    }
  ]
}
```

#### Direct Access (Port 7070) - Expected to Fail

Direct access to port 7070 will fail because the tracker is configured for reverse proxy mode:

```bash
# Test HTTP tracker directly on port 7070 (expected to fail)
echo "=== Testing HTTP Tracker Direct (7070) - Expected to fail ==="
cargo run -p torrust-tracker-client --bin http_tracker_client announce \
  http://$TARGET_SERVER:7070 \
  9c38422213e30bff212b30c360d26f9a02136422 | jq
```

**Expected Behavior**: Should fail with an error about missing `X-Forwarded-For`
header, confirming the tracker is correctly configured for reverse proxy mode.

### 3.3 Test API Endpoints

#### Health Check Endpoint - ✅ Working

```bash
# Test health check API through nginx proxy
echo "=== Testing Health Check API ==="
curl -s http://$TARGET_SERVER:80/api/health_check | jq
```

**Expected Output:**

```json
{
  "status": "Ok"
}
```

#### Statistics Endpoint - ✅ Working

The statistics API is available through the nginx proxy on port 80:

```bash
# Test statistics API through nginx proxy (requires admin token)
echo "=== Testing Statistics API ==="
curl -s "http://$TARGET_SERVER:80/api/v1/stats?token=MyAccessToken" | jq
```

**Expected Output:**

```json
{
  "torrents": 0,
  "seeders": 0,
  "completed": 0,
  "leechers": 0,
  "tcp4_connections_handled": 0,
  "tcp4_announces_handled": 0,
  "tcp4_scrapes_handled": 0,
  "tcp6_connections_handled": 0,
  "tcp6_announces_handled": 0,
  "tcp6_scrapes_handled": 0,
  "udp4_connections_handled": 0,
  "udp4_announces_handled": 0,
  "udp4_scrapes_handled": 0,
  "udp6_connections_handled": 0,
  "udp6_announces_handled": 0,
  "udp6_scrapes_handled": 0
}
```

#### Metrics Endpoint

```bash
# Test Prometheus metrics
echo "=== Testing Metrics Endpoint ==="
curl -s http://$TARGET_SERVER:1212/metrics | head -20
```

**Expected Output:** Prometheus-formatted metrics data.

### 3.4 Comprehensive Tracker Checker

> **Note**: The tracker checker is designed for production environments with
> HTTPS. For local testing without certificates, individual endpoint tests
> (above) are more reliable.

For completeness, here's how to use the tracker checker tool:

```bash
# Configure tracker checker for your environment
export TORRUST_CHECKER_CONFIG='{
    "udp_trackers": ["udp://'$TARGET_SERVER':6969/announce"],
    "http_trackers": ["http://'$TARGET_SERVER':80"],
    "health_checks": ["http://'$TARGET_SERVER':80/api/health_check"]
}'

# Run comprehensive checker
echo "=== Running Comprehensive Tracker Checker ==="
cargo run -p torrust-tracker-client --bin tracker_checker
```

**Expected Output:** Status report for all configured endpoints.

## Step 4: Interpret Results

### 4.1 Success Indicators

All tests should show:

- ✅ **UDP Trackers**: JSON responses with interval/peer data
- ✅ **HTTP Tracker** (via proxy): JSON response with tracker statistics
- ✅ **Health Check**: `{"status": "Ok"}` response
- ✅ **Statistics API** (via proxy): JSON with current tracker metrics
- ✅ **Metrics**: Prometheus-formatted data

### 4.2 Common Issues and Solutions

#### Connection Refused

```bash
# Check if services are running (must run from the application directory)
ssh torrust@$TARGET_SERVER \
  "cd /home/torrust/github/torrust/torrust-tracker-demo/application && docker compose ps"

# Check firewall rules
ssh torrust@$TARGET_SERVER "sudo ufw status"

# Restart services if needed (must run from the application directory)
ssh torrust@$TARGET_SERVER \
  "cd /home/torrust/github/torrust/torrust-tracker-demo/application && docker compose restart"
```

#### DNS Resolution Issues

```bash
# Test with IP address instead of hostname
TARGET_SERVER="192.168.1.100"  # Replace with actual IP

# Or add to /etc/hosts temporarily
echo "$TARGET_SERVER your-server.example.com" | sudo tee -a /etc/hosts
```

#### Certificate Issues (Future Production Testing)

> **Note**: This section will be expanded when Let's Encrypt automation
> is implemented.

For production environments with HTTPS certificates:

```bash
# Test HTTPS endpoints (future)
curl -s https://$TARGET_SERVER/api/health_check | jq

# Configure tracker checker for HTTPS (future)
export TORRUST_CHECKER_CONFIG='{
    "udp_trackers": ["udp://'$TARGET_SERVER':6969/announce"],
    "http_trackers": ["https://'$TARGET_SERVER'"],
    "health_checks": ["https://'$TARGET_SERVER'/api/health_check"]
}'
```

## Step 5: Automated Smoke Test Script (Optional)

For repeated testing, create an automated script:

```bash
# Create smoke test script
cat > smoke_test.sh << 'EOF'
#!/bin/bash
set -euo pipefail

TARGET_SERVER="${1:-localhost}"
INFOHASH="9c38422213e30bff212b30c360d26f9a02136422"

echo "=== Torrust Tracker Smoke Tests ==="
echo "Target: $TARGET_SERVER"
echo

# Test UDP Tracker 6868
echo "Testing UDP Tracker (6868)..."
if cargo run -p torrust-tracker-client --bin udp_tracker_client announce \
   udp://$TARGET_SERVER:6868/announce $INFOHASH >/dev/null 2>&1; then
    echo "✅ UDP 6868: PASS"
else
    echo "❌ UDP 6868: FAIL"
fi

# Test UDP Tracker 6969
echo "Testing UDP Tracker (6969)..."
if cargo run -p torrust-tracker-client --bin udp_tracker_client announce \
   udp://$TARGET_SERVER:6969/announce $INFOHASH >/dev/null 2>&1; then
    echo "✅ UDP 6969: PASS"
else
    echo "❌ UDP 6969: FAIL"
fi

# Test HTTP Tracker
echo "Testing HTTP Tracker (7070)..."
if cargo run -p torrust-tracker-client --bin http_tracker_client announce \
   http://$TARGET_SERVER:7070 $INFOHASH >/dev/null 2>&1; then
    echo "✅ HTTP 7070: PASS"
else
    echo "❌ HTTP 7070: FAIL"
fi

# Test Health Check
echo "Testing Health Check API..."
if curl -s http://$TARGET_SERVER:1212/api/health_check | grep -q "ok"; then
    echo "✅ Health Check: PASS"
else
    echo "❌ Health Check: FAIL"
fi

# Test Statistics
echo "Testing Statistics API..."
if curl -s http://$TARGET_SERVER:7070/api/v1/stats | grep -q "torrents"; then
    echo "✅ Statistics: PASS"
else
    echo "❌ Statistics: FAIL (expected due to proxy configuration)"
fi

echo
echo "=== Smoke Tests Complete ==="
echo "Note: HTTP tracker and statistics tests may fail due to reverse proxy configuration"
EOF

chmod +x smoke_test.sh

# Run smoke tests
./smoke_test.sh $TARGET_SERVER
```

## Step 6: Cleanup

```bash
# Return to original directory
cd ..

# Optional: Remove cloned repository if no longer needed
# rm -rf torrust-tracker
```

## Summary

This smoke testing guide provides a quick way to verify Torrust Tracker
functionality using official client tools. It's perfect for:

- **Post-deployment validation**
- **Quick health checks**
- **External testing perspective**
- **Protocol-level verification**

The tests cover all major Torrust Tracker components:

- UDP trackers (ports 6868, 6969)
- HTTP tracker (port 7070)
- REST API endpoints (health, statistics)
- Metrics collection (Prometheus format)

For more comprehensive testing including infrastructure validation, see the
[Integration Testing Guide](integration-testing-guide.md).

## Future Enhancements

This guide will be expanded to include:

- ✅ **HTTPS testing** with Let's Encrypt certificates
- ✅ **Performance benchmarking** with load testing
- ✅ **Multi-peer simulation** for realistic scenarios
- ✅ **Grafana dashboard validation**
- ✅ **Database consistency checks**

Stay tuned for updates as the Torrust Tracker Demo evolves!
