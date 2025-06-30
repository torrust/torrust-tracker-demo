#!/bin/bash

# Update the demo by updating the containers

cd /home/torrust/github/torrust/torrust-tracker-demo || exit
docker compose pull
docker compose down
docker compose up --build --detach
cd ~ || exit
