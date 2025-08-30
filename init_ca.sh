#!/bin/bash
set -e
DATA_DIR="$1"
if [ -z "$DATA_DIR" ]; then
  echo "Usage: $0 /path/to/data"
  exit 1
fi

mkdir -p "$DATA_DIR/root" "$DATA_DIR/intermediate"
chmod -R 700 "$DATA_DIR"

# Root CA config
ROOT_DIR="$DATA_DIR/root"
INT_DIR="$DATA_DIR/intermediate"

# create index and serial files for both
mkdir -p $ROOT_DIR/{certs,crl,newcerts,private}
mkdir -p $INT_DIR/{certs,crl,csr,newcerts,private}
touch $ROOT_DIR/index.txt $INT_DIR/index.txt
echo 1000 > $ROOT_DIR/serial
echo 1000 > $INT_DIR/serial
echo 1000 > $INT_DIR/crlnumber

# generate root key (EC prime256v1)
openssl ecparam -name prime256v1 -genkey -noout -out $ROOT_DIR/private/ca.key.pem
chmod 400 $ROOT_DIR/private/ca.key.pem

# generate root cert (self-signed)
openssl req -config /etc/ssl/openssl-root.cnf -key $ROOT_DIR/private/ca.key.pem \
    -new -x509 -days 3650 -sha256 -extensions v3_ca -out $ROOT_DIR/ca.crt.pem \
    -subj "/C=US/ST=CA/L=Local/O=Example Root CA/OU=Root/CN=Example Root CA"

chmod 444 $ROOT_DIR/ca.crt.pem

# generate intermediate key
openssl ecparam -name prime256v1 -genkey -noout -out $INT_DIR/private/inter.key.pem
chmod 400 $INT_DIR/private/inter.key.pem

# generate intermediate CSR
openssl req -config /etc/ssl/openssl-inter.cnf -new -sha256 \
    -key $INT_DIR/private/inter.key.pem -out $INT_DIR/inter.csr.pem \
    -subj "/C=US/ST=CA/L=Local/O=Example Intermediate/OU=Intermediate/CN=Example Intermediate CA"

# sign intermediate with root to create intermediate cert
openssl ca -config /etc/ssl/openssl-root.cnf -extensions v3_intermediate_ca \
    -days 3650 -notext -md sha256 -batch \
    -in $INT_DIR/inter.csr.pem -out $INT_DIR/certs/inter.crt.pem

chmod 444 $INT_DIR/certs/inter.crt.pem

# Create fullchain for distribution
cat $INT_DIR/certs/inter.crt.pem $ROOT_DIR/ca.crt.pem > $INT_DIR/certs/chain.pem
chmod 444 $INT_DIR/certs/chain.pem

# generate OCSP responder key (we'll use the intermediate cert as the signer)
openssl ecparam -name prime256v1 -genkey -noout -out /etc/ssl/ocsp/ocsp.key.pem
chmod 400 /etc/ssl/ocsp/ocsp.key.pem
cp $INT_DIR/certs/inter.crt.pem /etc/ssl/ocsp/ocsp.crt.pem

# create an initial CRL
openssl ca -config /etc/ssl/openssl-inter.cnf -gencrl -out $INT_DIR/crl/intermediate.crl.pem

echo "Root and intermediate CA created at $DATA_DIR"
