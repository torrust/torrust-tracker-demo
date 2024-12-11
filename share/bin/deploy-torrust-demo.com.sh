#!/bin/bash

# Update the demo by updating the containers

cd github/torrust/torrust-demo/
docker compose pull
docker compose down
docker compose up --build --detach
cd ~
