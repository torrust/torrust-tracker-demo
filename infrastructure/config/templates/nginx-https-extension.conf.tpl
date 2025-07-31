# Nginx HTTPS Extension Configuration Template for Torrust Tracker Demo
# This template adds HTTPS configuration to the existing HTTP configuration
# It should be appended to the HTTP configuration after SSL certificates are generated

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

    # SSL certificate configuration
    ssl_certificate /etc/letsencrypt/live/tracker.${DOMAIN_NAME}/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/tracker.${DOMAIN_NAME}/privkey.pem;

    # SSL optimization
    ssl_buffer_size 8k;
    ssl_dhparam /etc/ssl/certs/dhparam.pem;

    # SSL security configuration
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_prefer_server_ciphers on;
    ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384;
    ssl_ecdh_curve secp384r1;
    ssl_session_tickets off;

    # OCSP stapling
    ssl_stapling on;
    ssl_stapling_verify on;
    resolver 8.8.8.8 8.8.4.4 valid=300s;
    resolver_timeout 5s;

    # Tracker API endpoints
    location /api/ {
        proxy_pass http://tracker:1212/api/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;

        # Security headers
        add_header X-Frame-Options "SAMEORIGIN" always;
        add_header X-XSS-Protection "1; mode=block" always;
        add_header X-Content-Type-Options "nosniff" always;
        add_header Referrer-Policy "no-referrer-when-downgrade" always;
        add_header Content-Security-Policy "default-src 'self' http: https: data: blob: 'unsafe-inline'" always;
        # Uncomment the following line only if you understand HSTS implications
        # add_header Strict-Transport-Security "max-age=31536000; includeSubDomains; preload" always;
    }

    # Tracker HTTP endpoints
    location / {
        proxy_pass http://tracker:7070;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;

        # Security headers
        add_header X-Frame-Options "SAMEORIGIN" always;
        add_header X-XSS-Protection "1; mode=block" always;
        add_header X-Content-Type-Options "nosniff" always;
        add_header Referrer-Policy "no-referrer-when-downgrade" always;
        add_header Content-Security-Policy "default-src 'self' http: https: data: blob: 'unsafe-inline'" always;
        # Uncomment the following line only if you understand HSTS implications
        # add_header Strict-Transport-Security "max-age=31536000; includeSubDomains; preload" always;
    }

    root /var/www/html;
    index index.html index.htm index.nginx-debian.html;
}

# HTTPS server for grafana subdomain
server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name grafana.${DOMAIN_NAME};

    server_tokens off;

    # SSL certificate configuration
    ssl_certificate /etc/letsencrypt/live/grafana.${DOMAIN_NAME}/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/grafana.${DOMAIN_NAME}/privkey.pem;

    # SSL optimization
    ssl_buffer_size 8k;
    ssl_dhparam /etc/ssl/certs/dhparam.pem;

    # SSL security configuration
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_prefer_server_ciphers on;
    ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384;
    ssl_ecdh_curve secp384r1;
    ssl_session_tickets off;

    # OCSP stapling
    ssl_stapling on;
    ssl_stapling_verify on;
    resolver 8.8.8.8 8.8.4.4 valid=300s;
    resolver_timeout 5s;

    # Grafana web interface
    location / {
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_pass http://grafana;

        # Security headers
        add_header X-Frame-Options "SAMEORIGIN" always;
        add_header X-XSS-Protection "1; mode=block" always;
        add_header X-Content-Type-Options "nosniff" always;
        add_header Referrer-Policy "no-referrer-when-downgrade" always;
        add_header Content-Security-Policy "default-src 'self' http: https: data: blob: 'unsafe-inline' 'unsafe-eval'" always;
        # Uncomment the following line only if you understand HSTS implications
        # add_header Strict-Transport-Security "max-age=31536000; includeSubDomains; preload" always;
    }

    # Proxy Grafana Live WebSocket connections
    location /api/live/ {
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection $connection_upgrade;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_pass http://grafana;
    }

    root /var/www/html;
    index index.html index.htm index.nginx-debian.html;
}
