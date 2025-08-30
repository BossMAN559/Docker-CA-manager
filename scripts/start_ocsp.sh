#!/bin/bash
set -e
DATA_DIR=${DATA_DIR:-/data/ca}
INT_DIR="$DATA_DIR/intermediate"
ROOT_DIR="$DATA_DIR/root"

OCSP_PORT=2560
OCSP_KEY=/etc/ssl/ocsp/ocsp.key.pem
OCSP_CERT=/etc/ssl/ocsp/ocsp.crt.pem
OCSP_RESPFILE=/var/run/ocsp/ocsp.pid

# make sure index exists for OCSP
if [ ! -f "$INT_DIR/index.txt" ]; then
  touch "$INT_DIR/index.txt"
fi

# start openssl ocsp responder (use -index pointing to intermediate index file)
# Note: openssl ocsp will run in foreground
exec openssl ocsp -index "$INT_DIR/index.txt" -port $OCSP_PORT -rsigner "$OCSP_CERT" -rkey "$OCSP_KEY" -CA "$ROOT_DIR/ca.crt.pem" -text -out /dev/stdout
