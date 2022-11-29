#!/bin/bash

CERT_DEST_PATH="${1:-proxy.pem}"
CN_ARG="localhost"


openssl req -newkey rsa:2048 -new -nodes -x509 -days 365 -keyout key.pem -out cert.pem -subj "/C=PT/ST=Lisbon/L=Linho/O=MOV.AI/OU=DevOps Team/CN=$CN_ARG"

cat key.pem > "$CERT_DEST_PATH"
cat cert.pem >> "$CERT_DEST_PATH"