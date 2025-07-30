# Nginx HTTPS Configuration Template for Torrust Tracker Demo
# This template provides HTTPS configuration using self-signed certificates
# It is intended for development and testing environments

# WebSocket connection upgrade mapping for Grafana
map $http_upgrade $connection_upgrade {
    default upgrade;
    '' close;
}

# Upstream definition for Grafana
upstream grafana {
    server grafana:3000;
}

# HTTPS server for tracker subdomain
server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name tracker.${DOMAIN_NAME};

    server_tokens off;

    # Self-signed SSL certificate configuration
    ssl_certificate /etc/ssl/certs/tracker.${DOMAIN_NAME}.crt;
    ssl_certificate_key /etc/ssl/private/tracker.${DOMAIN_NAME}.key;

    # SSL optimization
    ssl_buffer_size 8k;

    # SSL security configuration (relaxed for self-signed certificates)
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_prefer_server_ciphers on;
    ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384;
    ssl_ecdh_curve secp384r1;
    ssl_session_tickets off;

    # Security headers
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
    add_header X-Frame-Options DENY always;
    add_header X-Content-Type-Options nosniff always;
    add_header X-XSS-Protection "1; mode=block" always;

    # Tracker API endpoints
    location /api/ {
        proxy_pass http://tracker:1212/api/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header X-Forwarded-Host $host;
        proxy_set_header X-Forwarded-Server $host;
    }

    # Tracker HTTP endpoints
    location / {
        proxy_pass http://tracker:7070;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header X-Forwarded-Host $host;
        proxy_set_header X-Forwarded-Server $host;
    }

    # Health check endpoint (accessible via HTTPS)
    location /health {
        access_log off;
        return 200 "healthy\n";
        add_header Content-Type text/plain;
    }
}

# HTTPS server for grafana subdomain
server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name grafana.${DOMAIN_NAME};

    server_tokens off;

    # Self-signed SSL certificate configuration
    ssl_certificate /etc/ssl/certs/grafana.${DOMAIN_NAME}.crt;
    ssl_certificate_key /etc/ssl/private/grafana.${DOMAIN_NAME}.key;

    # SSL optimization
    ssl_buffer_size 8k;

    # SSL security configuration (relaxed for self-signed certificates)
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_prefer_server_ciphers on;
    ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384;
    ssl_ecdh_curve secp384r1;
    ssl_session_tickets off;

    # Security headers
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
    add_header X-Frame-Options DENY always;
    add_header X-Content-Type-Options nosniff always;
    add_header X-XSS-Protection "1; mode=block" always;

    # Grafana web interface
    location / {
        proxy_pass http://grafana;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header X-Forwarded-Host $host;
        proxy_set_header X-Forwarded-Server $host;

        # WebSocket support for Grafana live features
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection $connection_upgrade;
        proxy_read_timeout 86400;
        proxy_buffering off;
    }

    # Health check endpoint
    location /health {
        access_log off;
        return 200 "healthy\n";
        add_header Content-Type text/plain;
    }
}

# HTTP to HTTPS redirect for tracker subdomain
server {
    listen 80;
    listen [::]:80;
    server_name tracker.${DOMAIN_NAME};

    # Allow Let's Encrypt ACME challenge (for future Let's Encrypt upgrade)
    location ~ /.well-known/acme-challenge {
        allow all;
        root /var/lib/torrust/certbot/webroot;
    }

    # Redirect all other HTTP traffic to HTTPS
    location / {
        return 301 https://$server_name$request_uri;
    }
}

# HTTP to HTTPS redirect for grafana subdomain
server {
    listen 80;
    listen [::]:80;
    server_name grafana.${DOMAIN_NAME};

    # Allow Let's Encrypt ACME challenge (for future Let's Encrypt upgrade)
    location ~ /.well-known/acme-challenge {
        allow all;
        root /var/lib/torrust/certbot/webroot;
    }

    # Redirect all other HTTP traffic to HTTPS
    location / {
        return 301 https://$server_name$request_uri;
    }
}
