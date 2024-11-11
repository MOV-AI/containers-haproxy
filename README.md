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
    - ha-backend-ros-tools : ros-tools container (`/ros-tools`)
    - ha-backend-ros-master : ros-master container
    - ha-backend-influxdb : influxdb container (`/influxdb`)


- Enabled static frontends:
  - ha-frontend-http : http, 80 and 443, ssl (`/monitoring` and `/influxdb` need authentication)
  - ha-frontend-redis-master : tcp 6379, ssl (outer interface)
  - ha-frontend-redis-slave : tcp 6379 (inner network)
  - ha-frontend-spawner : tcp, dynamic ports FMT_PORTS
  - ha-frontend-ros-master : http 11311 (no ssl, debug only)
  - ha-frontend-ros-tools : http 8901, ssl
  - admin_socket : admin socket for haproxy stats, 2000 (no ssl)


- Certificates generation for frontends that use SSL (http, redis-master, ros-tools) see [Certificates](#certificates) for more information

- Certificates verification for frontends that use SSL (http, redis-master, ros-tools) see [Certificates verification](#certificates-verification) for more information

- Authentication is required for the `/monitoring` and `/influxdb` paths in the `ha-frontend-http` frontend.


## Authenticated users

The `ha-frontend-http` frontend requires authentication for the `/monitoring` and `/influxdb` paths.
The username and password are set in the `haproxy.cfg` file and are `admin` and `admin123` respectively.

- To add more users dynamically to this group, the `haproxy.cfg` file can be updated with the new user's credentials.
  Passwords should be hashed using the `mkpasswd` command as follows:

```bash
mkpasswd -m sha-256 <password>
```

- To remove a user from the group, the `haproxy.cfg` file can be updated to remove the user.
- The `haproxy.cfg` file should be updated with the new user's credentials and the container should be restarted to apply the changes.

## Certificates

Server SSL certificates are generated on the fly for the frontends that require them (http, redis-master, ros-tools).
Certificates are stored in `/etc/ssl/private` and are valid for 2 years

> [!TIP]
> All useful certificates information is displayed in the logs at the start of the container.

### Server Certificates generation
Server Certificates can be generated inside the container using the `generate-cert.sh` script as follows during runtime:

```bash
/usr/local/etc/haproxy/gen_cert.sh <options>
```
where `<options>` can be:
```
--ssl_dest_dir: The directory to save the certificate to (default: '/etc/ssl/private')
--cert_dest_path: The path to save the certificate to (default: 'proxy.pem')
--ca_cert_path: The path to the CA certificate to sign the certificate with (default: 'ca.pem')
--ca_key_path: The path to the CA key to sign the certificate with (default: 'ca-key.pem')
--cn: The common name to use for the certificate (default: 'localhost')
--alt_names: The alternative names to use for the certificate in comma-separated format (default: 'localhost,127.0.0.1,standalone.mov.ai')
--days: The number of days the certificate will be valid for (default: 720)
--key_size: The size of the RSA key to use for the certificate (default: 2048)
--gen_client_cert: Generate a client certificate signed by the proxy's certificate authority with the DNS names given here (default: same as server certificate)
--help: Display this help message
```

> [!NOTE]
> A docker exec command should be used to run the script inside the running container as stated above.

### Client Certificates generation

Client Certificates can be generated using the `generate-cert.sh` script as follows:

```bash
/usr/local/etc/haproxy/gen_cert.sh --gen_client_cert=<client_names>
```
where `<client_names>` is a comma separated list of client names.
This will generate a client certificate signed by the proxy's certificate authority with the DNS names given in `<client_names>` and print its information to the console so that it can be saved to a file and then imported into the browser using the printed password.

> [!NOTE]
> A docker exec command should be used to run the script inside the running container as stated above.

Example of ouput:
```
./scripts/gen_cert.sh --gen_client_cert --cn=foobar --alt_names=foobar,foobar.example.
com --ssl_dest_dir=$PWD
--- Generating CA certificate and key ---
CA certificate path: /home/afe/workspace/containers-haproxy/ca.pem
CA key path: /home/afe/workspace/containers-haproxy/ca-key.pem
CA certificate and key already exist
/home/afe/workspace/containers-haproxy/ca.pem: OK
Certificate will not expire
--- Generating certificate ---
Certificate will not expire
--- Certificate already exists and is valid ---
--- Certificate information to be used by clients ---
...
--- Client certificate in PKCS#12 format to be imported into Chrome ---
To store the client certificate in a file, run the following command:
echo "MIILXgIBAzC...==" | base64 -d > client.p12
--- Client PKCS#12 password: ******************** ---
```

### Certificates verification

The certificates verification is recommended only in the `release` environment.
The verification is done by checking the certificate chain and its certificate authority (CA) using the `verify` option in the `bind` directive in the haproxy configuration file.

> [!IMPORTANT]
> If the certificates verification is enabled, the untrusted clients will not be able to connect to the frontends.
> In order to connect, the clients must use a valid certificate signed by the CA used by the frontends.
> So, for example, if the `ha-frontend-ros-tools` frontend is configured to verify the certificates, the clients must use a valid certificate to connect to `https://<hostname>:8901/` which should be generated as follows:
> ```bash
> # hostname of client is 'client_hostname' or 'client_hostname.example.com'
> /usr/local/etc/haproxy/gen_cert.sh --gen_client_cert=client_hostname,client_hostname.example.com
> ```

When using QA configuration, haproxy can be reconfigured to verify or not the certificates by setting:
- the `HTTPS_VERIFY` environment variable to `true` or `false` for the `ha-frontend-http` frontend
- the `ROS_TOOLS_VERIFY` environment variable to `true` or `false` for the `ha-frontend-ros-tools` frontend
- the `REDIS_VERIFY` environment variable to `true` or `false` for the `ha-frontend-redis-master` frontend

Those environment variables are set to `false` by default in `/usr/local/bin/movai-entrypoint.sh`.
Easy way to change the value is to override the entrypoint script with a custom value:
```bash
docker exec -itu root <container_id> /usr/bin/sed -i 's/HTTPS_VERIFY="false"/HTTPS_VERIFY="true"/' /usr/local/bin/movai-entrypoint.sh
```

### Certificates renewal

The certificates are not renewed automatically. The certificates are generated at the start of the container and are valid for 2 years.
They should be regenerated manually using the `generate-cert.sh` script.

### Browsers certificate warning

When connecting to the frontends using a browser, a warning message may appear indicating that the certificate is not trusted.
This is because the certificate is self-signed and not signed by a trusted certificate authority.
To avoid this warning, the browser should be configured to trust the certificate authority used to sign the certificate (CA) or to use the client certificate generated by the `generate-cert.sh` script.

On Chrome, the client certificate of .p12 format can be added to the trusted certificate authorities by following these steps:
1. Open the Chrome settings
2. Go to the `Privacy and security` section
3. Click on `Security`
4. Click on `Manage certificates`
5. Go to the `Your certificates` tab
6. Click on `Import` and select the .p12 file generated by the `generate-cert.sh` script
7. Enter the password used to generate the certificate

