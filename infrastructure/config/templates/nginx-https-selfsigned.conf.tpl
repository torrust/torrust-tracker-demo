# Nginx HTTPS Configuration Template for Torrust Tracker Demo
# This template provides HTTPS configuration using self-signed certificates
# It is intended for development and testing environments

# WebSocket connection upgrade mapping for Grafana
map ${DOLLAR}http_upgrade ${DOLLAR}connection_upgrade {
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
        proxy_set_header Host ${DOLLAR}host;
        proxy_set_header X-Real-IP ${DOLLAR}remote_addr;
        proxy_set_header X-Forwarded-For ${DOLLAR}proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto ${DOLLAR}scheme;
        proxy_set_header X-Forwarded-Host ${DOLLAR}host;
        proxy_set_header X-Forwarded-Server ${DOLLAR}host;
    }

    # Tracker HTTP endpoints
    location / {
        proxy_pass http://tracker:7070;
        proxy_set_header Host ${DOLLAR}host;
        proxy_set_header X-Real-IP ${DOLLAR}remote_addr;
        proxy_set_header X-Forwarded-For ${DOLLAR}proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto ${DOLLAR}scheme;
        proxy_set_header X-Forwarded-Host ${DOLLAR}host;
        proxy_set_header X-Forwarded-Server ${DOLLAR}host;
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
        proxy_set_header Host ${DOLLAR}host;
        proxy_set_header X-Real-IP ${DOLLAR}remote_addr;
        proxy_set_header X-Forwarded-For ${DOLLAR}proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto ${DOLLAR}scheme;
        proxy_set_header X-Forwarded-Host ${DOLLAR}host;
        proxy_set_header X-Forwarded-Server ${DOLLAR}host;

        # WebSocket support for Grafana live features
        proxy_http_version 1.1;
        proxy_set_header Upgrade ${DOLLAR}http_upgrade;
        proxy_set_header Connection ${DOLLAR}connection_upgrade;
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

# HTTP server configuration (parallel to HTTPS for Let's Encrypt and testing)
#
# These HTTP servers run alongside HTTPS servers to provide:
# 1. Let's Encrypt ACME challenge support on port 80
# 2. HTTP endpoint testing for integration tests
# 3. Certificate renewal automation support
# 4. Fallback access during certificate issues

# HTTP server for tracker subdomain
server {
    listen 80;
    listen [::]:80;

    root /var/www/html;
    index index.html index.htm index.nginx-debian.html;

    server_name tracker.${DOMAIN_NAME};

    # Tracker API endpoints (HTTP access)
    location /api/ {
        proxy_pass http://tracker:1212/api/;
        proxy_set_header X-Forwarded-For ${DOLLAR}proxy_add_x_forwarded_for;
        proxy_set_header Host ${DOLLAR}host;
        proxy_set_header X-Real-IP ${DOLLAR}remote_addr;
        proxy_set_header X-Forwarded-Proto ${DOLLAR}scheme;
    }

    # Tracker HTTP endpoints
    location / {
        proxy_pass http://tracker:7070;
        proxy_set_header X-Forwarded-For ${DOLLAR}proxy_add_x_forwarded_for;
        proxy_set_header Host ${DOLLAR}host;
        proxy_set_header X-Real-IP ${DOLLAR}remote_addr;
        proxy_set_header X-Forwarded-Proto ${DOLLAR}scheme;
    }

    # Let's Encrypt ACME challenge
    location ~ /.well-known/acme-challenge {
        allow all;
        root /var/lib/torrust/certbot/webroot;
    }

    # Health check endpoint
    location /health {
        access_log off;
        return 200 "healthy\n";
        add_header Content-Type text/plain;
    }
}

# HTTP server for grafana subdomain
server {
    listen 80;
    listen [::]:80;

    root /var/www/html;
    index index.html index.htm index.nginx-debian.html;

    server_name grafana.${DOMAIN_NAME};

    # Grafana web interface (HTTP access)
    location / {
        proxy_pass http://grafana;
        proxy_set_header Host ${DOLLAR}host;
        proxy_set_header X-Real-IP ${DOLLAR}remote_addr;
        proxy_set_header X-Forwarded-For ${DOLLAR}proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto ${DOLLAR}scheme;

        # WebSocket support for Grafana live features
        proxy_http_version 1.1;
        proxy_set_header Upgrade ${DOLLAR}http_upgrade;
        proxy_set_header Connection ${DOLLAR}connection_upgrade;
        proxy_read_timeout 86400;
        proxy_buffering off;
    }

    # Let's Encrypt ACME challenge
    location ~ /.well-known/acme-challenge {
        allow all;
        root /var/lib/torrust/certbot/webroot;
    }

    # Health check endpoint
    location /health {
        access_log off;
        return 200 "healthy\n";
        add_header Content-Type text/plain;
    }
}

# HTTP to HTTPS redirect configuration (COMMENTED OUT)
#
# IMPORTANT: HTTP to HTTPS redirects are intentionally commented out because:
#
# 1. Let's Encrypt Certificate Generation:
#    - Let's Encrypt requires port 80 to be available for ACME HTTP-01 challenge
#    - Domain validation fails if all HTTP traffic is redirected to HTTPS
#    - Certificate generation scripts need HTTP access for domain verification
#
# 2. Certificate Renewal:
#    - Automatic certificate renewal also requires port 80 for challenge validation
#    - Redirects would break the renewal process, causing certificate expiration
#
# 3. Testing and Development:
#    - Integration tests expect HTTP endpoints to work for validation
#    - Mixed HTTP/HTTPS access needed for comprehensive endpoint testing
#    - Self-signed certificate environments don't require strict HTTPS enforcement
#
# 4. Manual Enablement:
#    - System administrators can manually enable these redirects after:
#      a) Successful Let's Encrypt certificate installation
#      b) Implementing alternative domain validation methods (DNS-01 challenge)
#      c) Ensuring certificate renewal automation works with redirects
#
# To enable HTTP to HTTPS redirects (advanced users only):
# 1. Uncomment the server blocks below
# 2. Ensure Let's Encrypt renewal uses DNS-01 challenge or webroot exception
# 3. Test certificate renewal before enabling in production
# 4. Consider leaving .well-known/acme-challenge accessible via HTTP

# server {
#     listen 80;
#     listen [::]:80;
#     server_name tracker.${DOMAIN_NAME};
# 
#     # Allow Let's Encrypt ACME challenge (required even with redirects)
#     location ~ /.well-known/acme-challenge {
#         allow all;
#         root /var/lib/torrust/certbot/webroot;
#     }
# 
#     # Redirect all other HTTP traffic to HTTPS
#     location / {
#         return 301 https://${DOLLAR}server_name${DOLLAR}request_uri;
#     }
# }

# server {
#     listen 80;
#     listen [::]:80;
#     server_name grafana.${DOMAIN_NAME};
# 
#     # Allow Let's Encrypt ACME challenge (required even with redirects)
#     location ~ /.well-known/acme-challenge {
#         allow all;
#         root /var/lib/torrust/certbot/webroot;
#     }
# 
#     # Redirect all other HTTP traffic to HTTPS
#     location / {
#         return 301 https://${DOLLAR}server_name${DOLLAR}request_uri;
#     }
# }
