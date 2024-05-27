#!/bin/bash
#
# Copyright 2021 MOV.AI
#
#    Licensed under the Mov.AI License version 1.0;
#    you may not use this file except in compliance with the License.
#    You may obtain a copy of the License at
#
#        https://www.mov.ai/flow-license/
#
#    Unless required by applicable law or agreed to in writing, software
#    distributed under the License is distributed on an "AS IS" BASIS,
#    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#    See the License for the specific language governing permissions and
#    limitations under the License.
#
# File: docker-entrypoint.sh

HTTPS_VERIFY="false"
REDIS_VERIFY="false"
ROS_TOOLS_VERIFY="false"

# if commands passed
[ $# -gt 0 ] && exec "$@"
# else

# Generate the certificates
if [ ! -f "/etc/ssl/private/proxy.pem" ]; then
    GEN_CERT_OPTS=""
    if [ -n "${PUBLIC_IP}" ]; then
        CN_ARG="${PUBLIC_IP}"
        GEN_CERT_OPTS="${GEN_CERT_OPTS} --cn ${CN_ARG}"
    fi

    if [ -n "${DNS_ALT_NAMES}" ]; then
        ALT_NAMES_ARG="${DNS_ALT_NAMES}"
        GEN_CERT_OPTS="${GEN_CERT_OPTS} --alt_names ${ALT_NAMES_ARG}"
    fi
    /usr/local/etc/haproxy/gen_cert.sh ${GEN_CERT_OPTS}
fi

test -z "${SPAWNER_PORTS}" && SPAWNER_PORTS='disabled'

if [ -f "/usr/local/etc/haproxy/haproxy.cfg" ]; then
    CONFIG_FILE="/usr/local/etc/haproxy/haproxy.cfg"
else
    test -z "${MOVAI_ENV}" && MOVAI_ENV='release'
    CONFIG_FILE="/usr/local/etc/haproxy/haproxy_${MOVAI_ENV}.cfg"
fi

printf "Replacing config ports: %s\n" "${SPAWNER_PORTS}"
printf "Using config file:      %s\n" "${CONFIG_FILE}"

sed -Ei "s/\{FMT_PORTS\}/${SPAWNER_PORTS}/" "${CONFIG_FILE}"

# Set the SSL verification mode for HTTPS frontend
if [ "${HTTPS_VERIFY}" = "true" ]; then
    export HTTPS_VERIFY="required"
else
    export HTTPS_VERIFY="none"
fi

# Set the SSL verification mode for ROS Tools frontend
if [ "${ROS_TOOLS_VERIFY}" = "true" ]; then
    export ROS_TOOLS_VERIFY="required"
else
    export ROS_TOOLS_VERIFY="none"
fi

# Set the SSL verification mode for Redis frontend
if [ "${VERIFY_REDIS_CERTS}" = "true" ]; then
    export REDIS_SSL_VERIFY="required"
else
    export REDIS_SSL_VERIFY="none"
fi

# Start the HAProxy
/usr/local/bin/docker-entrypoint.sh -f "${CONFIG_FILE}"
