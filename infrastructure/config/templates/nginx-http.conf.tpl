# Nginx HTTP Configuration Template for Torrust Tracker Demo
# This template provides HTTP-only configuration for initial deployment
# HTTPS configuration should be added using the nginx-https-extension.conf.tpl

# HTTP server for tracker subdomain
server {
    listen 80;
    listen [::]:80;

    root /var/www/html;
    index index.html index.htm index.nginx-debian.html;

    server_name tracker.${DOMAIN_NAME};

    # Tracker API endpoints
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
}

# HTTP server for grafana subdomain
server {
    listen 80;
    listen [::]:80;

    root /var/www/html;
    index index.html index.htm index.nginx-debian.html;

    server_name grafana.${DOMAIN_NAME};

    # Grafana web interface
    location / {
        proxy_pass http://grafana:3000;
        proxy_set_header Host ${DOLLAR}host;
        proxy_set_header X-Real-IP ${DOLLAR}remote_addr;
        proxy_set_header X-Forwarded-For ${DOLLAR}proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto ${DOLLAR}scheme;
    }

    # Let's Encrypt ACME challenge
    location ~ /.well-known/acme-challenge {
        allow all;
        root /var/lib/torrust/certbot/webroot;
    }
}
