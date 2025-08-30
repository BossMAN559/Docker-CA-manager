#!/bin/bash
set -e

TYPE=$1
NAME=$2
EMAIL=$3

if [ -z "$TYPE" ] || [ -z "$NAME" ]; then
    echo "Usage: $0 <type: admin|user|server|smartcard> <common_name> [email]"
    exit 1
fi

BASE=/data/ca
INTER=$BASE/intermediate
OUT=/data/issued
mkdir -p $OUT

KEY=$OUT/$NAME.key.pem
CSR=$OUT/$NAME.csr.pem
CERT=$OUT/$NAME.crt.pem
PFX=$OUT/$NAME.pfx

# Select extension based on type
case "$TYPE" in
    admin)
        EXT="admin_cert"
        ;;
    user)
        EXT="usr_cert"
        ;;
    server)
        EXT="server_cert"
        ;;
    smartcard)
        EXT="smartcard_cert"
        ;;
    *)
        echo "Invalid type: $TYPE"
        exit 1
        ;;
esac

echo "[*] Generating EC key for $TYPE certificate..."
openssl ecparam -genkey -name prime256v1 -out $KEY

echo "[*] Creating CSR..."
SUBJ="/CN=$NAME"
if [ -n "$EMAIL" ]; then
    SUBJ="$SUBJ/emailAddress=$EMAIL"
fi

openssl req -new -key $KEY -out $CSR -subj "$SUBJ"

echo "[*] Signing certificate with intermediate CA ($EXT)..."
openssl ca -config $INTER/openssl-inter.cnf \
  -extensions $EXT -days 825 -notext -md sha256 \
  -in $CSR -out $CERT -batch

chmod 600 $KEY
chmod 644 $CERT

echo "[*] Exporting PKCS#12 (PFX) bundle..."
openssl pkcs12 -export \
  -inkey $KEY -in $CERT -certfile $INTER/certs/ca-chain.pem \
  -out $PFX -passout pass:changeit

echo "[*] Done."
echo "  Key:   $KEY"
echo "  Cert:  $CERT"
echo "  PFX:   $PFX"
