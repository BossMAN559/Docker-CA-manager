#!/bin/bash
set -e
# usage: revoke_cert.sh <cert-pem>
DATA_DIR=${DATA_DIR:-/data/ca}
INT_DIR="$DATA_DIR/intermediate"

CERT="$1"
if [ -z "$CERT" ] || [ ! -f "$CERT" ]; then
  echo "Provide the certificate path to revoke."
  exit 1
fi

# revoke using openssl ca
openssl ca -config /etc/ssl/openssl-inter.cnf -revoke "$CERT"

# regenerate CRL
openssl ca -config /etc/ssl/openssl-inter.cnf -gencrl -out "$INT_DIR/crl/intermediate.crl.pem"

echo "Revoked $CERT and generated new CRL at $INT_DIR/crl/intermediate.crl.pem"
