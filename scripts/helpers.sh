#!/bin/bash
set -e

DATA_DIR=${DATA_DIR:-/data/ca}
INT_DIR="$DATA_DIR/intermediate"

fingerprint_pem() {
  # prints SHA256 fingerprint of certificate file provided as $1
  openssl x509 -noout -in "$1" -fingerprint -sha256 | sed 's/^.*=//; s/://g' | tr '[:upper:]' '[:lower:]'
}
