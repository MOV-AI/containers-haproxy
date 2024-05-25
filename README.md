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

- Enabled static frontends:
  - ha-frontend-http : http, 80 and 443, ssl
  - ha-frontend-redis-master : tcp 6379, ssl (outer interface)
  - ha-frontend-redis-slave : tcp 6379 (inner network)
  - ha-frontend-spawner : tcp, dynamic ports FMT_PORTS

- Certificates:
  - SSL certificates are generated on the fly for the frontends that require them
  - Certificates are stored in `/etc/ssl/private` and are valid for 2 years
  - Server Certificates can be generated using the `generate-cert.sh` script as follows:
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

