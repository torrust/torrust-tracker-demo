#!/bin/bash

# It filter out known error log messages from the tracker logs
docker compose logs -f tracker | grep -v -F -e "Invalid announce event" -e 'Connection cookie error' -e INFO -e "Invalid action" -e "Udp::run_udp_server::loop aborting request" -e "Port can't be 0" -e "Protocol identifier missing" -e "Couldn't parse action"
