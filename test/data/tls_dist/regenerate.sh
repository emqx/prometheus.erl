#!/bin/sh

set -eu

cd "$(dirname "$0")"

openssl req \
  -x509 \
  -newkey rsa:2048 \
  -nodes \
  -keyout key.pem \
  -out cert.pem \
  -subj "/CN=localhost" \
  -days 3650
