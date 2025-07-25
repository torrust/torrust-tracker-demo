# Nginx Configuration Template for Torrust Tracker Demo
#
# Variable Escaping Notes:
# - This template is processed by envsubst which substitutes all $VARIABLE patterns
# - Nginx variables (like $proxy_add_x_forwarded_for, $host, $http_upgrade) must be escaped
# - Use ${DOLLAR} environment variable to represent literal $ in nginx config
# - Example: ${DOLLAR}proxy_add_x_forwarded_for becomes $proxy_add_x_forwarded_for
#
# TODO: Fix the commented HTTPS configuration section below
# - The HTTPS configuration has inconsistent variable escaping
# - Some nginx variables use literal $ (incorrect) while others should use ${DOLLAR}
# - Line 117: proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for; (needs ${DOLLAR})
# - Lines with $host, $http_upgrade, $connection_upgrade also need escaping
# - SSL certificate paths and other static values are correct as-is

server
{
    listen 80;
    listen [::]:80;

    root /var/www/html;
    index index.html index.htm index.nginx-debian.html;

    server_name tracker.torrust-demo.com;

    location /api/
    {
            proxy_pass http://tracker:1212/api/;
            proxy_set_header X-Forwarded-For ${DOLLAR}proxy_add_x_forwarded_for;
    }

    location /
    {
            proxy_pass http://tracker:7070;
            proxy_set_header X-Forwarded-For ${DOLLAR}proxy_add_x_forwarded_for;
    }

    location ~ /.well-known/acme-challenge
    {
            allow all;
            root /var/www/html;
    }
}

server
{
    listen 80;
    listen [::]:80;

    root /var/www/html;
    index index.html index.htm index.nginx-debian.html;

    server_name grafana.torrust-demo.com;

    location /
    {
            proxy_pass http://grafana:3000;
    }

    location ~ /.well-known/acme-challenge
    {
            allow all;
            root /var/www/html;
    }
}

#server
#{
#    listen 443 ssl http2;
#    listen [::]:443 ssl http2;
#    server_name tracker.torrust-demo.com;
#
#    server_tokens off;
#
#    ssl_certificate /etc/letsencrypt/live/tracker.torrust-demo.com/fullchain.pem;
#    ssl_certificate_key /etc/letsencrypt/live/tracker.torrust-demo.com/privkey.pem;
#
#    ssl_buffer_size 8k;
#
#    ssl_dhparam /etc/ssl/certs/dhparam-2048.pem;
#
#    ssl_protocols TLSv1.2;
#    ssl_prefer_server_ciphers on;
#
#    ssl_ciphers ECDH+AESGCM:ECDH+AES256:ECDH+AES128:DH+3DES:!ADH:!AECDH:!MD5;
#
#    ssl_ecdh_curve secp384r1;
#    ssl_session_tickets off;
#
#    ssl_stapling on;
#    ssl_stapling_verify on;
#    resolver 8.8.8.8;
#
#    location /api/
#    {
#        try_files $uri @tracker-api;
#    }
#
#    location /
#    {
#        try_files $uri @tracker-http;
#    }
#
#    location @tracker-api
#    {
#        proxy_pass http://tracker:1212;
#        add_header X-Frame-Options "SAMEORIGIN" always;
#        add_header X-XSS-Protection "1; mode=block" always;
#        add_header X-Content-Type-Options "nosniff" always;
#        add_header Referrer-Policy "no-referrer-when-downgrade" always;
#        add_header Content-Security-Policy "default-src * data: 'unsafe-eval' 'unsafe-inline'" always;
#        #add_header Strict-Transport-Security "max-age=31536000; includeSubDomains; preload" always;
#        # enable strict transport security only if you understand the implications
#    }
#
#    location @tracker-http
#    {
#        proxy_pass http://tracker:7070;
#        add_header X-Frame-Options "SAMEORIGIN" always;
#        add_header X-XSS-Protection "1; mode=block" always;
#        add_header X-Content-Type-Options "nosniff" always;
#        add_header Referrer-Policy "no-referrer-when-downgrade" always;
#        add_header Content-Security-Policy "default-src * data: 'unsafe-eval' 'unsafe-inline'" always;
#        #add_header Strict-Transport-Security "max-age=31536000; includeSubDomains; preload" always;
#        # enable strict transport security only if you understand the implications
#
#    proxy_set_header X-Forwarded-For ${DOLLAR}proxy_add_x_forwarded_for;
#    }
#
#    root /var/www/html;
#    index index.html index.htm index.nginx-debian.html;
#}

## This is required to proxy Grafana Live WebSocket connections.
#map $http_upgrade $connection_upgrade {
#  default upgrade;
#  '' close;
#}
#
#upstream grafana {
#  server grafana:3000;
#}
#
#server
#{
#        listen 443 ssl http2;
#        listen [::]:443 ssl http2;
#        server_name grafana.torrust-demo.com;
#
#        server_tokens off;
#
#        ssl_certificate /etc/letsencrypt/live/grafana.torrust-demo.com/fullchain.pem;
#        ssl_certificate_key /etc/letsencrypt/live/grafana.torrust-demo.com/privkey.pem;
#
#        ssl_buffer_size 8k;
#
#        ssl_dhparam /etc/ssl/certs/dhparam-2048.pem;
#
#        ssl_protocols TLSv1.2;
#        ssl_prefer_server_ciphers on;
#
#        ssl_ciphers ECDH+AESGCM:ECDH+AES256:ECDH+AES128:DH+3DES:!ADH:!AECDH:!MD5;
#
#        ssl_ecdh_curve secp384r1;
#        ssl_session_tickets off;
#
#        ssl_stapling on;
#        ssl_stapling_verify on;
#        resolver 8.8.8.8;
#
#        location / {
#                proxy_set_header Host $host;
#                proxy_pass http://grafana;
#        }
#
#        # Proxy Grafana Live WebSocket connections.
#        location /api/live/ {
#                proxy_http_version 1.1;
#                proxy_set_header Upgrade $http_upgrade;
#                proxy_set_header Connection $connection_upgrade;
#                proxy_set_header Host $host;
#                proxy_pass http://grafana;
#        }
#
#        root /var/www/html;
#        index index.html index.htm index.nginx-debian.html;
#}