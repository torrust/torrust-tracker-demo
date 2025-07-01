# Sample Commands

- `docker ps`: list containers.
- `docker compose logs -f`: print all containers' logs.
- `docker compose logs -f tracker`: print tracker container' logs.
- `docker compose logs -f tracker | head -n100`: print the first 100 lines in the tracker container log.
- `docker compose logs -f | grep "ERROR"`: print logs showing only errors.
