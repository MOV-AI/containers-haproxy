#!/bin/bash

# Generate a self-signed certificate for the proxy
# The certificate will be signed by a self-signed certificate authority or by a verifiable certificate authority (CA)
# The certificate will be generated with a 2048-bit RSA key
# The certificate will be valid for 720 days
# The certificate will be saved in PEM format, with the private key first and the certificate second
#
# Usage: ./gen_cert.sh [CERT_DEST_PATH]

# Default values
SSL_DEST_DIR="/etc/ssl/private"
CERT_DEST_PATH="proxy.pem"
CA_CERT_PATH="ca.pem"
CA_KEY_PATH="ca-key.pem"
CN_ARG="localhost"
ALT_NAMES_ARG="localhost,127.0.0.1,standalone.mov.ai"
DAYS=730
KEY_SIZE=2048
HELP="false"
VERBOSE="false"
GEN_CLIENT_CERT="false"
GEN_CLIENT_CERT_ARG=""

# Functions
function print_help {
    echo "Generate a self-signed certificate for the proxy"
    echo "The certificate will be signed by a self-signed certificate authority or by a verifiable certificate authority"
    echo "The certificate will be saved in PEM format, with the private key first and the certificate second"
    echo ""
    echo "Arguments:"
    echo "  --ssl_dest_dir: The directory to save the certificate to (default: '/etc/ssl/private')"
    echo "  --cert_dest_path: The path to save the certificate to (default: 'proxy.pem')"
    echo "  --ca_cert_path: The path to the CA certificate to sign the certificate with (default: 'ca.pem')"
    echo "  --ca_key_path: The path to the CA key to sign the certificate with (default: 'ca-key.pem')"
    echo "  --cn: The common name to use for the certificate (default: 'localhost')"
    echo "  --alt_names: The alternative names to use for the certificate in comma-separated format (default: 'localhost,127.0.0.1,standalone.mov.ai')"
    echo "  --days: The number of days the certificate will be valid for (default: 720)"
    echo "  --key_size: The size of the RSA key to use for the certificate (default: 2048)"
    echo "  --gen_client_cert: Generate a client certificate signed by the proxy's certificate authority with the DNS names given here (default: same as server certificate)"
    echo "  --help: Display this help message"
    echo "Usage: ./gen_cert.sh [options]"
    }

function generate_ca_cert {
    echo "--- Generating CA certificate and key ---"
    echo "CA certificate path: $CA_CERT_PATH"
    echo "CA key path: $CA_KEY_PATH"


    if [ ! -f "$CA_CERT_PATH" ] || [ ! -f "$CA_KEY_PATH" ]; then
        echo "CA certificate and key not found, generating new ones"
        openssl req -x509 -newkey rsa:$KEY_SIZE -nodes -keyout "$CA_KEY_PATH" -out "$CA_CERT_PATH" -days $DAYS -subj "$SUBJ" -extensions v3_ca -config <(cat /etc/ssl/openssl.cnf <(printf "[v3_ca]\nsubjectAltName = $ALT_NAMES"))
    else
        echo "CA certificate and key already exist"
        # verify the validity of the CA certificate
        openssl verify -CAfile "$CA_CERT_PATH" "$CA_CERT_PATH"
        if [ $? -ne 0 ]; then
            echo "Error: CA certificate is not valid"
            exit 1
        fi
        # check if CA has expired
        openssl x509 -checkend $((2 * 24 * 3600)) -noout -in "$CA_CERT_PATH"
        if [ $? -ne 0 ]; then
            echo "Error: CA certificate will expire soon"
            exit 1
        fi
        # print the CA certificate information
        # openssl x509 -in "$CA_CERT_PATH" -text -noout
    fi
}

function generate_cert {
    echo "--- Generating certificate ---"

    if [ -f "$CA_CERT_PATH" ] && [ -f "$CA_KEY_PATH" ]; then
        # If the certificate exists, check if it is valid and will not expire soon
        if [ -f "$CERT_DEST_PATH" ]; then
            openssl x509 -checkend $((2 * 24 * 3600)) -noout -in "$CERT_DEST_PATH"
            if [ $? -eq 0 ]; then
                echo "--- Certificate already exists and is valid ---"
                return
            fi
        fi
        openssl req -newkey rsa:$KEY_SIZE -nodes -keyout key.pem -out csr.pem -subj "$SUBJ" -extensions v3_req -config <(cat /etc/ssl/openssl.cnf <(printf "[v3_req]\nsubjectAltName = $ALT_NAMES"))
        openssl x509 -req -in csr.pem -CA "$CA_CERT_PATH" -CAkey "$CA_KEY_PATH" -CAcreateserial -out cert.pem -days $DAYS -extensions v3_req -extfile <(cat /etc/ssl/openssl.cnf <(printf "[v3_req]\nsubjectAltName = $ALT_NAMES"))
        cat key.pem > "$CERT_DEST_PATH"
        cat cert.pem >> "$CERT_DEST_PATH"
        rm csr.pem key.pem cert.pem
        echo "--- Certificate generated successfully ---"
    else
        echo "Error: CA certificate and key not found"
        exit 1
    fi
}

function print_ca_cert_info {
    echo "--- CA information to be trusted by clients ---"
    openssl x509 -in "$CA_CERT_PATH" -text -noout
    echo "--- CA information to be copied to clients ---"
    cat "$CA_CERT_PATH"
}

function gen_client_cert {
    echo "--- Certificate information to be used by clients ---"
    if [ -z "$1" ]; then
        echo "Info: No alternative names provided for the client certificate"
        CLIENT_ALT_NAMES="$ALT_NAMES"
        CLIENT_CN="$CN_ARG"
    else
        CLIENT_ALT_NAMES_ARG="$1"
        CLIENT_ALT_NAMES=""
        for ALT_NAME in $(echo $CLIENT_ALT_NAMES_ARG | tr "," "\n")
        do
            CLIENT_ALT_NAMES="DNS:$ALT_NAME,$CLIENT_ALT_NAMES"
        done
        CLIENT_ALT_NAMES="${CLIENT_ALT_NAMES::-1}"
        # first alternative name is the common name of the client certificate
        CLIENT_CN="${CLIENT_ALT_NAMES_ARG%%,*}"
    fi

    CLIENT_CERT_PATH="client-${CLIENT_CN}.crt"
    CLIENT_KEY_PATH="client-${CLIENT_CN}.key"
    CLIENT_CSR_PATH="client-${CLIENT_CN}.csr"
    CLIENT_PEM_PATH="client-${CLIENT_CN}.pem"
    CLIENT_P12_PATH="client-${CLIENT_CN}.p12"
    CLIENT_SUBJ="/C=PT/ST=Lisbon/L=Lisbon/O=MOV.AI/OU=DevOps Team/CN=${CLIENT_CN}"
    openssl req -newkey rsa:$KEY_SIZE -nodes -keyout "$CLIENT_KEY_PATH" -out "$CLIENT_CSR_PATH" -subj "$CLIENT_SUBJ" -extensions v3_req -config <(cat /etc/ssl/openssl.cnf <(printf "[v3_req]\nsubjectAltName = $CLIENT_ALT_NAMES"))
    openssl x509 -req -in "$CLIENT_CSR_PATH" -CA "$CA_CERT_PATH" -CAkey "$CA_KEY_PATH" -CAcreateserial -out "$CLIENT_CERT_PATH" -days $DAYS -extensions v3_req -extfile <(cat /etc/ssl/openssl.cnf <(printf "[v3_req]\nsubjectAltName = $CLIENT_ALT_NAMES"))
    openssl x509 -in "$CLIENT_CERT_PATH" -text -noout

    # Generate a PKCS#12 file from the client certificate and key
    CLIENT_P12_PASS="$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1)"
    openssl pkcs12 -export -out "$CLIENT_P12_PATH" -inkey "$CLIENT_KEY_PATH" -in "$CLIENT_CERT_PATH" -name "MOV.AI Proxy Client Certificate" -passout pass:"$CLIENT_P12_PASS" -CAfile "$CA_CERT_PATH" -caname "MOV.AI Proxy CA"

    echo "--- Client certificate in PKCS#12 format to be imported into Chrome ---"
    echo "To store the client certificate in a file, run the following command:"
    echo "echo \"$(base64 -w 0 "$CLIENT_P12_PATH")\" | base64 -d > client.p12"
    echo "--- Client PKCS#12 password: $CLIENT_P12_PASS ---"
}


# Parse arguments
for i in "$@"
do
case $i in
    --ssl_dest_dir=*)
    SSL_DEST_DIR="${i#*=}"
    shift
    ;;
    --cert_dest_path=*)
    CERT_DEST_PATH="${i#*=}"
    shift
    ;;
    --ca_cert_path=*)
    CA_CERT_PATH="${i#*=}"
    shift
    ;;
    --ca_key_path=*)
    CA_KEY_PATH="${i#*=}"
    shift
    ;;
    --cn=*)
    CN_ARG="${i#*=}"
    shift
    ;;
    --alt_names=*)
    ALT_NAMES_ARG="${i#*=}"
    shift
    ;;
    --days=*)
    DAYS="${i#*=}"
    shift
    ;;
    --key_size=*)
    KEY_SIZE="${i#*=}"
    shift
    ;;
    --gen_client_cert)
    GEN_CLIENT_CERT="true"
    shift
    ;;
    --gen_client_cert=*)
    GEN_CLIENT_CERT="true"
    GEN_CLIENT_CERT_ARG="${i#*=}"
    shift
    ;;
    --help)
    HELP="true"
    shift
    ;;
    --verbose)
    VERBOSE="true"
    shift
    ;;
    *)
    # unknown option
    echo -e "\nError: Unknown option: $i\n"
    HELP="true"
    shift
    ;;
esac
done

# Display help message
if [ "$HELP" = "true" ]; then
    print_help
    exit 0
fi

# Check if the SSL destination directory exists
if [ ! -d "$SSL_DEST_DIR" ]; then
    echo "Error: SSL destination directory does not exist"
    exit 1
fi

# if the paths are absolute, use them as is else append the SSL_DEST_DIR to them
if [[ ! "$CERT_DEST_PATH" =~ ^/ ]]; then
    CERT_DEST_PATH="${SSL_DEST_DIR}/${CERT_DEST_PATH}"
fi
if [[ ! "$CA_CERT_PATH" =~ ^/ ]]; then
    CA_CERT_PATH="${SSL_DEST_DIR}/${CA_CERT_PATH}"
fi
if [[ ! "$CA_KEY_PATH" =~ ^/ ]]; then
    CA_KEY_PATH="${SSL_DEST_DIR}/${CA_KEY_PATH}"
fi

# Format the subject with the common name
SUBJ="/C=PT/ST=Lisbon/L=Lisbon/O=MOV.AI/OU=DevOps Team/CN=$CN_ARG"

# Format the alternative names for openssl config
ALT_NAMES="DNS:$CN_ARG"
if [ -n "$ALT_NAMES_ARG" ]; then
    for ALT_NAME in $(echo $ALT_NAMES_ARG | tr "," "\n")
    do
        ALT_NAMES="$ALT_NAMES,DNS:$ALT_NAME"
    done
fi

# Generate the CA certificate and key
generate_ca_cert

# Generate the server certificate
generate_cert

# Print the certificate information
if [ "$VERBOSE" = "true" ]; then
    print_ca_cert_info
fi

# Generate a client certificate signed by the proxy's certificate authority
if [ "$GEN_CLIENT_CERT" = "true" ]; then
    gen_client_cert "$GEN_CLIENT_CERT_ARG"
fi



