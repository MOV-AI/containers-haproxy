ARG HAPROXY_VERSION="lts"
FROM haproxy:${HAPROXY_VERSION}

# Labels
LABEL description="MOV.AI Load Balancer Image"
LABEL maintainer="devops@mov.ai"
LABEL movai="haproxy"

USER root

# SSL Certificates directory
VOLUME [ "/etc/ssl/private/" ]

# SSL Certificate generation script
COPY --chown=haproxy:haproxy scripts/gen_cert.sh /usr/local/etc/haproxy/

# Set user rights
RUN chown haproxy:haproxy /usr/local/etc/haproxy /run/ /etc/ssl -R \
 && chmod +x /usr/local/etc/haproxy/gen_cert.sh \
 && apt-get update \
 && apt-get install -y --no-install-recommends socat \
 && apt-get clean \
 && rm -rf /var/lib/apt/lists/*

USER haproxy

# Configuration files
COPY common_files/503-movai.http /etc/503-movai.http
COPY config/dev/haproxy_develop.cfg \
    config/qa/haproxy_qa.cfg \
    config/release/haproxy_release.cfg \
    /usr/local/etc/haproxy/

# Cors lua script
COPY common_files/cors.lua /usr/local/etc/haproxy/cors.lua

# Custom entrypoint
COPY common_files/movai-entrypoint.sh /usr/local/bin/

ENTRYPOINT [ "/usr/local/bin/movai-entrypoint.sh" ]
