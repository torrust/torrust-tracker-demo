# Grafana Setup Guide - Torrust Tracker Monitoring

This guide covers the manual setup and configuration of Grafana for monitoring your
Torrust Tracker deployment. Grafana provides powerful dashboards and visualization
capabilities for tracker metrics and system monitoring.

## Overview

After deploying the Torrust Tracker with the included Docker Compose configuration,
Grafana is available but requires manual setup to:

- Secure the default admin account
- Configure Prometheus as a data source
- Import pre-built dashboards (optional)
- Create custom dashboards (optional)

This process is intentionally manual to allow users flexibility in customizing their
monitoring setup according to their specific needs.

## Prerequisites

- Torrust Tracker deployed with Docker Compose (local or cloud)
- Grafana service running (included in the Docker Compose stack)
- Prometheus service running (included in the Docker Compose stack)
- Access to the Grafana web interface

## Step 1: Initial Login

### Access Grafana

1. **For local deployment**:

   ```bash
   # Access via browser
   open http://localhost:3100/
   ```

2. **For remote deployment**:

   ```bash
   # Replace <server-ip> with your actual server IP
   open http://<server-ip>:3100/
   ```

### Default Credentials

- **Username**: `admin`
- **Password**: `admin`

**Important**: You will be prompted to change the password immediately after first login.

## Step 2: Secure Admin Account

### Change Default Password

1. After logging in with `admin/admin`, Grafana will prompt you to change the password
2. Choose a strong password and confirm the change
3. **Record this password securely** - you'll need it for future access

### Alternative: Skip Password Change (Not Recommended)

If you're in a development environment, you can skip the password change, but this
is **not recommended** for any deployment that might be accessible from outside
your local machine.

## Step 3: Configure Prometheus Data Source

### Add Prometheus Data Source

1. **Navigate to Data Sources**:

   - Click the gear icon (⚙️) in the left sidebar
   - Select "Data sources"
   - Click "Add data source"

2. **Select Prometheus**:

   - Click on "Prometheus" from the list of available data sources

3. **Configure Connection**:

   - **Name**: `Prometheus` (or any name you prefer)
   - **URL**:
     - For local deployment: `http://prometheus:9090`
     - For remote deployment: `http://prometheus:9090`

   **Note**: Use the Docker container name `prometheus` since Grafana runs in the
   same Docker network as Prometheus.

4. **Test Connection**:
   - Scroll down and click "Save & Test"
   - You should see a green "Data source is working" message

### Verify Metrics Availability

1. **Navigate to Explore**:

   - Click the compass icon (🧭) in the left sidebar
   - Select your Prometheus data source

2. **Test a Query**:
   - In the query box, type: `torrust_tracker_announces_total`
   - Click "Run Query" or press Shift+Enter
   - You should see metrics data if the tracker is running and processing requests

## Step 4: Import Pre-built Dashboards (Optional)

The repository includes pre-built Grafana dashboards that provide comprehensive
monitoring for the Torrust Tracker.

### Locate Dashboard Files

The dashboard backups are located in:

```bash
application/share/grafana/dashboards/
```

### Import Dashboard Method 1: JSON Import

1. **Navigate to Dashboard Import**:

   - Click the "+" icon in the left sidebar
   - Select "Import"

2. **Import JSON**:

   - Click "Upload JSON file"
   - Navigate to `application/share/grafana/dashboards/`
   - Select a dashboard file (`stats.json` or `metrics.json`)
   - Click "Load"

3. **Configure Import**:
   - Review the dashboard name and UID
   - Select your Prometheus data source from the dropdown
   - Click "Import"

### Import Dashboard Method 2: Copy-Paste

1. **Open Dashboard File**:

   ```bash
   # View dashboard JSON content (example with stats dashboard)
   cat application/share/grafana/dashboards/stats.json
   ```

2. **Copy JSON Content**:

   - Copy the entire JSON content from the file

3. **Import in Grafana**:
   - In Grafana, go to "+" → "Import"
   - Paste the JSON content in the text area
   - Click "Load" and configure as above

### Available Dashboard Types

The repository includes pre-built dashboard configurations:

- **`stats.json`**: Dashboard using metrics from the tracker's `/api/v1/stats` endpoint
- **`metrics.json`**: Dashboard using metrics from the tracker's `/api/v1/metrics` endpoint

These dashboards provide:

- **Tracker Overview**: General tracker metrics and performance
- **API Monitoring**: Tracker API endpoint statistics and response times
- **System Analytics**: Connection counts, bandwidth, and operational metrics

**Note**: Check the `application/share/grafana/dashboards/README.md` for the latest
information about available dashboard configurations.

## Step 5: Verify Dashboard Functionality

### Check Data Display

1. **Open Imported Dashboard**:

   - Navigate to "Dashboards" (four squares icon) in the left sidebar
   - Click on your imported dashboard

2. **Verify Metrics**:
   - Panels should display data if the tracker is active
   - If panels show "No data", verify:
     - Prometheus data source is configured correctly
     - Tracker is running and processing requests
     - Time range is appropriate (try "Last 1 hour" or "Last 6 hours")

### Troubleshooting Empty Dashboards

If dashboards appear empty:

1. **Check Time Range**:

   - Use the time picker in the top-right corner
   - Try "Last 1 hour" or "Last 24 hours"

2. **Verify Data Source**:

   - Go to dashboard settings (gear icon)
   - Ensure the correct Prometheus data source is selected

3. **Test Queries Manually**:
   - Go to "Explore" and test individual metrics
   - Common tracker metrics to test:
     - `torrust_tracker_announces_total`
     - `torrust_tracker_scrapes_total`
     - `torrust_tracker_connections_total`

## Step 6: Create Custom Dashboards (Optional)

### Create New Dashboard

1. **Start New Dashboard**:

   - Click "+" → "Dashboard"
   - Click "Add visualization"

2. **Select Data Source**:

   - Choose your Prometheus data source

3. **Configure Panel**:

   - **Query**: Enter a Prometheus query (e.g., `rate(torrust_tracker_announces_total[5m])`)
   - **Visualization**: Choose chart type (Time series, Stat, Gauge, etc.)
   - **Panel title**: Give your panel a descriptive name

4. **Save Dashboard**:
   - Click "Save" (disk icon)
   - Provide a name and optional description
   - Choose a folder or leave in "General"

### Common Tracker Metrics

Here are some useful metrics to monitor:

```promql
# Announce rate (requests per second)
rate(torrust_tracker_announces_total[5m])

# Active torrents count
torrust_tracker_torrents

# Active peers (seeders + leechers)
torrust_tracker_seeders + torrust_tracker_leechers

# Error rate
rate(torrust_tracker_errors_total[5m])

# Response time percentiles
histogram_quantile(0.95, rate(torrust_tracker_response_time_seconds_bucket[5m]))
```

## Configuration Examples

### Example Prometheus Configuration

If you need to verify your Prometheus configuration, it should include:

```yaml
# prometheus.yml (for reference)
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: "torrust-tracker"
    static_configs:
      - targets: ["tracker:1212"] # Tracker metrics endpoint
    metrics_path: "/metrics"
    scrape_interval: 10s
```

### Example Dashboard Panel Query

For a panel showing announce rate:

```json
{
  "expr": "rate(torrust_tracker_announces_total[5m])",
  "legendFormat": "Announces per second",
  "refId": "A"
}
```

## Maintenance and Updates

### Regular Maintenance

1. **Monitor Disk Usage**:

   - Prometheus data grows over time
   - Configure retention policies if needed

2. **Dashboard Updates**:

   - Check repository for updated dashboard files
   - Import new versions when available

3. **Security**:
   - Regularly update Grafana admin password
   - Consider setting up additional user accounts

### Backup Dashboards

To backup your custom dashboards:

1. **Export Dashboard**:

   - Open dashboard settings (gear icon)
   - Click "JSON Model"
   - Copy the JSON content

2. **Save to File**:

   ```bash
   # Save your custom dashboard
   echo '{"dashboard": {...}}' > my-custom-dashboard.json
   ```

## Troubleshooting

### Common Issues

#### 1. Cannot Access Grafana

```bash
# Check if Grafana container is running
docker compose ps grafana

# Check Grafana logs
docker compose logs grafana

# Restart Grafana if needed
docker compose restart grafana
```

#### 2. Prometheus Data Source Not Working

```bash
# Check if Prometheus is running
docker compose ps prometheus

# Test Prometheus endpoint
curl http://localhost:9090/api/v1/query?query=up

# Check Prometheus logs
docker compose logs prometheus
```

#### 3. No Metrics Data

```bash
# Check if tracker metrics endpoint is working
curl http://localhost:1212/metrics

# Verify tracker is processing requests
# Make some announce requests to generate metrics
```

#### 4. Dashboard Import Fails

- Verify JSON syntax is valid
- Check that the data source UID matches your Prometheus configuration
- Try importing individual panels instead of the full dashboard

### Getting Help

- **Grafana Documentation**: [https://grafana.com/docs/](https://grafana.com/docs/)
- **Prometheus Documentation**: [https://prometheus.io/docs/](https://prometheus.io/docs/)
- **Project Issues**: [GitHub Issues](https://github.com/torrust/torrust-tracker-demo/issues)

## Next Steps

After setting up Grafana:

1. **Configure Alerting** (optional): Set up alerts for critical metrics
2. **Create User Accounts** (optional): Add additional users for team access
3. **Customize Dashboards**: Modify imported dashboards to fit your needs
4. **Set Up Long-term Storage** (optional): Configure long-term metrics retention

## Security Notes

### Production Considerations

- **Change default passwords** immediately
- **Restrict network access** to Grafana (firewall rules)
- **Use HTTPS** for production deployments
- **Regular backups** of dashboard configurations
- **Monitor access logs** for unauthorized access attempts

### Network Security

By default, Grafana runs on port 3100. In production:

- Consider putting Grafana behind a reverse proxy
- Use HTTPS with proper SSL certificates
- Implement proper authentication (OAuth, LDAP, etc.)
- Restrict access to monitoring networks only

## Conclusion

This guide provides the essential steps for setting up Grafana monitoring for your
Torrust Tracker deployment. The manual setup process allows for flexibility in
customizing your monitoring solution to meet specific requirements.

While the basic setup is straightforward, Grafana offers extensive customization
options for advanced users who want to create sophisticated monitoring and alerting
systems.
