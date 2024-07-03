#!/bin/bash

# Update the demo by updating the containers

cd github/torrust/torrust-compose/droplet/
docker compose pull
docker compose down
docker compose up --build --detach
cd ~
