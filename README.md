# Zabbix 7 All-in-One Appliance

Docker-based **Zabbix 7 All-in-One** image with all major components running in a single container:

* PostgreSQL 16
* Zabbix Server 7
* Zabbix Web
* Nginx
* PHP-FPM
* Supervisor

The container automatically initializes PostgreSQL and the Zabbix database on the first start.

> **This is not an official Zabbix Appliance.**
> It is a community-built image intended primarily for development, testing, PoC and small standalone environments.

## Quick Start

### Docker

```bash
docker volume create zabbix-data

docker run -d \
  --name zabbix \
  -p 8080:8080 \
  -p 10051:10051 \
  -e POSTGRES_PASSWORD='change-me' \
  -v zabbix-data:/var/lib/postgresql/data \
  <IMAGE_NAME>
```

Zabbix Web:

```text
http://localhost:8080
```

Zabbix Server:

```text
localhost:10051
```

### Docker Compose

```yaml
services:
  zabbix:
    image: <IMAGE_NAME>
    container_name: zabbix
    restart: unless-stopped

    ports:
      - "8080:8080"
      - "10051:10051"

    environment:
      POSTGRES_DB: zabbix
      POSTGRES_USER: zabbix
      POSTGRES_PASSWORD: change-me
      POSTGRES_PORT: 5432
      POSTGRES_VERSION: 16

    volumes:
      - zabbix-data:/var/lib/postgresql/data

volumes:
  zabbix-data:
```

Start:

```bash
docker compose up -d
```

## Environment Variables

| Variable            | Default                    | Description               |
| ------------------- | -------------------------- | ------------------------- |
| `POSTGRES_DB`       | `zabbix`                   | Database name             |
| `POSTGRES_USER`     | `zabbix`                   | Database user             |
| `POSTGRES_PASSWORD` | **required**               | Database password         |
| `POSTGRES_PORT`     | `5432`                     | PostgreSQL port           |
| `POSTGRES_VERSION`  | `16`                       | PostgreSQL major version  |
| `PGDATA`            | `/var/lib/postgresql/data` | PostgreSQL data directory |

## Data Persistence

PostgreSQL data is stored in:

```text
/var/lib/postgresql/data
```

Mount a persistent volume to keep monitoring data between container recreations:

```yaml
volumes:
  - zabbix-data:/var/lib/postgresql/data
```

On the first start, the entrypoint automatically:

1. Initializes PostgreSQL;
2. Creates the database and user;
3. Initializes the Zabbix database schema;
4. Generates `zabbix_server.conf`;
5. Starts all services via Supervisor.

On subsequent starts, the existing database is reused.

## Ports

|    Port | Service       |
| ------: | ------------- |
|  `8080` | Zabbix Web    |
| `10051` | Zabbix Server |

PostgreSQL is available internally on port `5432` and does not need to be exposed externally.

## Production

This image is designed for **development, testing, PoC and small standalone deployments**.

For production environments, consider running PostgreSQL, Zabbix Server and Zabbix Web as separate services. This provides better scalability, availability, backup and upgrade flexibility.

## Disclaimer

This project is **not affiliated with or endorsed by Zabbix SIA**.

Zabbix is a trademark of Zabbix SIA.
