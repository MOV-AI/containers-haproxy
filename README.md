# Haproxy for MOV.AI

## Build

    docker build --pull -t haproxy:movai .

## Run

    export MOVAI_ENV=release
    docker run -it -e MOVAI_ENV haproxy:latest

## Features
- Multiple configurations switching based on MOVAI_ENV value

- Enabled static backends:
    - ha-backend-manager : manager container (`/manager`)
    - ha-backend-monitoring : monitoring container (`/monitoring`)
    - ha-backend-health-node : health-node container (`/health`)
    - ha-backend-http : backend container (`/`)
    - ha-backend-redis-master : redis-master container
    - ha-backend-redis-slave : redis-slave container
    - ha-backend-spawner : spawner container

- Enabled static frontends:
  - ha-frontend-http : http, 80 and 443, ssl
  - ha-frontend-redis-master : tcp 6379, ssl (outer interface)
  - ha-frontend-redis-slave : tcp 6379 (inner network)
  - ha-frontend-spawner : tcp, dynamic ports FMT_PORTS
  - ha-frontend-manager : http, 8443, ssl
