#!/bin/bash

# Print the time running a given container.
#
# For example:
#
# ./bin/time-running.sh tracker
# Container tracker has been running for 851 seconds.

# Get the container ID as an argument
container_id="${1}"

# Get the start time of the container
start_time=$(docker inspect --format='{{.State.StartedAt}}' "${container_id}")

# Calculate the number of seconds the container has been running
start_timestamp=$(date -d "${start_time}" +%s)
current_timestamp=$(date +%s)
seconds_running=$((current_timestamp - start_timestamp))

echo "Container ${container_id} has been running for ${seconds_running} seconds."