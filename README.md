# Haproxy for MOV.AI

## Build

    docker build --pull -t haproxy:movai .

## Run

    export MOVAI_ENV=release
    docker run -it -e MOVAI_ENV haproxy:movai

## Features
- Multiple configurations switching based on MOVAI_ENV value

- Enabled static backends:
    - ha-backend-monitoring : monitoring container (`/monitoring`)
    - ha-backend-health-node : health-node container (`/health`)
    - ha-backend-http : backend container (`/`)
    - ha-backend-redis-master : redis-master container
    - ha-backend-redis-slave : redis-slave container
    - ha-backend-spawner : spawner container
    - ha-backend-ros-tools : ros-tools container
    - ha-backend-ros-master : ros-master container


- Enabled static frontends:
  - ha-frontend-http : http, 80 and 443, ssl
  - ha-frontend-redis-master : tcp 6379, ssl (outer interface)
  - ha-frontend-redis-slave : tcp 6379 (inner network)
  - ha-frontend-spawner : tcp, dynamic ports FMT_PORTS
  - ha-frontend-ros-master : http 11311 (no ssl, debug only)
  - ha-frontend-ros-tools : http 8901, ssl
  - admin_socket : admin socket for haproxy stats, 2000 (no ssl)

## Certificates
  - SSL certificates are generated on the fly for the frontends that require them (http, redis-master, ros-tools)
  - Certificates are stored in `/etc/ssl/private` and are valid for 2 years
  - Server Certificates can be generated using the `generate-cert.sh` script as follows during runtime:

    ```bash
    /usr/local/etc/haproxy/gen_cert.sh <options>
    ```
    where `<options>` can be:
    ```
      --cert_dest_path: The path to save the certificate to (default: 'proxy.pem')
      --ca_cert_path: The path to the CA certificate to sign the certificate with (default: 'ca.pem')
      --ca_key_path: The path to the CA key to sign the certificate with (default: 'ca-key.pem')
      --cn: The common name to use for the certificate (default: 'localhost')
      --alt_names: The alternative names to use for the certificate in comma-separated format (default: 'localhost,127.0.0.1,standalone.mov.ai')
      --days: The number of days the certificate will be valid for (default: 720)
      --key_size: The size of the RSA key to use for the certificate (default: 2048)
      --gen_client_cert: Generate a client certificate signed by the proxy's certificate authority with the DNS names given here (default: same as server certificate)
    ```
  - Client Certificates can be generated using the `generate-cert.sh` script as follows:
    ```bash
    /usr/local/etc/haproxy/gen_cert.sh --gen_client_cert=<client_names>
    ```
    where `<client_names>` is a comma separated list of client names

### Certificates verification

The certificates verification is enabled only in the `release` environment. The verification is done by checking the certificate chain and its certificate authority. The CA is stored in `/etc/ssl/private/ca.pem` and is generated using the `generate-cert.sh` script.

> All useful certificates information is displayed in the logs at the start of the container.

When using QA configuration, haproxy can be reconfigured to verify or not the certificates by setting:
- the `HTTPS_VERIFY` environment variable to `true` or `false` for the `ha-frontend-http` frontend
- the `ROS_TOOLS_VERIFY` environment variable to `true` or `false` for the `ha-frontend-ros-tools` frontend
- the `REDIS_VERIFY` environment variable to `true` or `false` for the `ha-frontend-redis-master` frontend

Those environment variables are set to `false` by default in `/usr/local/bin/movai-entrypoint.sh`.
Easy way to change the value is to override the entrypoint script with a custom value:
```bash
docker exec -itu root <container_id> /usr/bin/sed -i 's/HTTPS_VERIFY="false"/HTTPS_VERIFY="true"/' /usr/local/bin/movai-entrypoint.sh
```


