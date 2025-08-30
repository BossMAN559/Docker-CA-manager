# cert-manager-nginx-php

Build:
docker build -t cert-manager:latest .

Run with persistent volume:
docker run -d --name cert-manager -p 443:443 -p 2560:2560 -v certdata:/data/ca cert-manager:latest

Visit https://host/ — on first run you will be presented with a "create admin certificate" form. Create it and download the admin key/cert/pfx. Import the admin cert into your browser or client and use it to access the Admin Panel.

Key files on the host volume:
- /data/ca/root/ca.crt.pem            (root cert)
- /data/ca/root/private/ca.key.pem    (root private key - keep safe; this file is created by init script but you may choose to delete it and keep offline)
- /data/ca/intermediate/*             (intermediate CA and issued certs)

OCSP responder runs on port 2560 in the container (http). CRL located at /data/ca/intermediate/crl/intermediate.crl.pem

Important: before production use, review TLS cipher suites, protect private keys, and consider adding HTTPS client cert pinning and passphrases for PFX files.
