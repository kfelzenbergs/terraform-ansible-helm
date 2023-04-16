#!/bin/bash

openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout tls.key -out tls.crt -subj "/CN=immudb-example.localhost"

TLS_CRT=$(cat tls.crt | base64)
TLS_KEY=$(cat tls.key | base64)
OUTFILE=tlsSecret


rm -rf $OUTFILE && touch $OUTFILE
tee -a $OUTFILE > /dev/null << EOF
tls.crt: |
  $TLS_CRT
tls.key: |
  $TLS_KEY
EOF
