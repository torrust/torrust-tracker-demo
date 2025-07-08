# Production Environment Setup

This guide details the steps required to configure the production environment
for the Torrust Tracker demo.

## 1. Initial Setup

For the initial server setup, follow the instructions on [Deploying Torrust To Production](https://torrust.com/blog/deploying-torrust-to-production).

You also need to enable a [firewall](./firewall-requirements.md).

The application is located in the directory: `/home/torrust/github/torrust/torrust-tracker-demo`.

To run Docker Compose commands, you need to be in the application directory:

```console
cd /home/torrust/github/torrust/torrust-tracker-demo
```

## 2. Database Configuration

The production environment uses MySQL as the database backend.

### Environment Variables

Create a `.env` file by copying the production template:

```bash
cp .env.production .env
```

**Crucially, you must edit the `.env` file and set secure passwords** for the following variables:

- `MYSQL_ROOT_PASSWORD`: The root password for the MySQL server.
- `MYSQL_PASSWORD`: The password for the `torrust` user.
- `TRACKER_ADMIN_TOKEN`: The admin token for the tracker API.

### Database Initialization

The MySQL service automatically initializes the database and creates the necessary tables on first startup.

## 3. Running the Application

Once the `.env` file is configured, you can start all services:

```bash
docker compose up -d
```

You can check the status of the services with:

```bash
docker compose ps
```
