#!/bin/bash

if ! [ -f "./.env" ]; then
	echo "Creating compose .env './.env'"
	cp .env.production .env
fi

## Proxy

mkdir -p ./storage/proxy/etc/nginx-conf
mkdir -p ./storage/proxy/webroot
mkdir -p ./storage/dhparam

if ! [ -f "./storage/proxy/etc/nginx-conf/nginx.conf" ]; then
	echo "Creating proxy config file: './storage/proxy/etc/nginx-conf/nginx.conf'"
	cp ./share/container/default/config/nginx.conf ./storage/proxy/etc/nginx-conf/nginx.conf
fi

## Certbot

mkdir -p ./storage/certbot/etc
mkdir -p ./storage/certbot/lib

## Tracker

# Generate the Tracker sqlite database directory and file if it does not exist
mkdir -p ./storage/tracker/lib/database

if ! [ -f "./storage/tracker/lib/database/sqlite3.db" ]; then
	echo "Creating tracker database: './storage/tracker/lib/database/sqlite3.db'"
	sqlite3 "./storage/tracker/lib/database/sqlite3.db" "VACUUM;"
fi

mkdir -p ./storage/tracker/etc

if ! [ -f "./storage/tracker/etc/tracker.prod.container.sqlite3.toml" ]; then
	echo "Crating tracker configuration: './storage/tracker/etc/tracker.toml'"
	cp ./share/container/default/config/tracker.prod.container.sqlite3.toml ./storage/tracker/etc/tracker.toml
fi

## Prometheus

mkdir -p ./storage/prometheus/etc

if ! [ -f "./storage/prometheus/etc/prometheus.yml" ]; then
	echo "Creating prometheus config file: './storage/prometheus/etc/prometheus.yml'"
	cp ./share/container/default/config/prometheus.yml ./storage/prometheus/etc/prometheus.yml
fi