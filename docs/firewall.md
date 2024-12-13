# Firewall

We are using a Digital Ocean Firewall.

![Firewall Rules](./do-firewall-configuration.png)

This is especially important for Prometheus service because it does not have authentication. This should not be exposed:

<http://grafana.torrust-demo.com:9090>

The port 80 is not enabled but you need to temporarily enable it to generate new Let's Encrypt certificates.
