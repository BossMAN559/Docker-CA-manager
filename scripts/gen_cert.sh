#!/bin/bash
set -e
# usage: gen_cert.sh <common-name> <type> <out-prefix>
# type: user|smartcard|web|admin
DATA_DIR=${DATA_DIR:-/data/ca}
INT_DIR="$DATA_DIR/intermediate"

CN="$1"
TYPE="$2"
OUT_PREFIX="${3:-$CN}"

if [ -z "$CN" ] || [ -z "$TYPE" ]; then
  echo "Usage: $0 <common-name> <type:user|smartcard|web|admin> [out-prefix]"
  exit 1
fi

KEY="$INT_DIR/private/${OUT_PREFIX}.key.pem"
CSR="$INT_DIR/csr/${OUT_PREFIX}.csr.pem"
CERT="$INT_DIR/certs/${OUT_PREFIX}.crt.pem"
PFX="$INT_DIR/certs/${OUT_PREFIX}.pfx"

mkdir -p "$INT_DIR/csr" "$INT_DIR/private" "$INT_DIR/certs"

# generate EC key
openssl ecparam -name prime256v1 -genkey -noout -out "$KEY"
chmod 400 "$KEY"

# create CSR
openssl req -new -key "$KEY" -out "$CSR" -subj "/CN=$CN/O=Example/$TYPE"

# sign with intermediate CA
openssl ca -config /etc/ssl/openssl-inter.cnf -extensions usr_cert -days 825 -notext -md sha256 -in "$CSR" -out "$CERT" -batch
chmod 444 "$CERT"

# create a pfx if needed (user will be able to download)
openssl pkcs12 -export -inkey "$KEY" -in "$CERT" -certfile $INT_DIR/certs/chain.pem -out "$PFX" -passout pass:
# empty password by default; admin can repackage later with passphrase

# output details
echo "CERT=$CERT"
echo "KEY=$KEY"
echo "PFX=$PFX"
