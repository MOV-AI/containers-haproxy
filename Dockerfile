ARG HAPROXY_VERSION="lts"
FROM haproxy:${HAPROXY_VERSION}

# Labels
LABEL description="MOV.AI Load Balancer Image"
LABEL maintainer="devops@mov.ai"
LABEL movai="haproxy"

USER root
# Set user rights
RUN chown haproxy:haproxy /usr/local/etc/haproxy /run/ -R

USER haproxy

# Configuration files
COPY common_files/503-movai.http /etc/503-movai.http
COPY config/dev/haproxy_develop.cfg \
    config/qa/haproxy_qa.cfg \
    config/release/haproxy_release.cfg \
    /usr/local/etc/haproxy/

# SSL Certificate
COPY common_files/proxy.pem /etc/ssl/private/proxy.pem

# Custom entrypoint
COPY common_files/movai-entrypoint.sh /usr/local/bin/

ENTRYPOINT [ "/usr/local/bin/movai-entrypoint.sh" ]
