#!/bin/bash
DATA_DIR=${DATA_DIR:-/data/ca}
INT_DIR="$DATA_DIR/intermediate"

openssl ca -config /etc/ssl/openssl-inter.cnf -gencrl -out "$INT_DIR/crl/intermediate.crl.pem"
echo "CRL regenerated at $INT_DIR/crl/intermediate.crl.pem"
