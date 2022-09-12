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

# if commands passed
[ $# -gt 0 ] && exec "$@"
# else

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

/usr/local/bin/docker-entrypoint.sh -f "${CONFIG_FILE}"
