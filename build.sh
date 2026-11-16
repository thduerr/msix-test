#!/usr/bin/env bash
# Builds and signs HelloWorld.msix on Linux/macOS.
# Requires: go, python3, openssl, osslsigncode (2.6+)
set -euo pipefail
cd "$(dirname "$0")"
mkdir -p pkg/Assets
(cd src && GOOS=windows GOARCH=amd64 go build -ldflags "-H=windowsgui -s -w" -o ../pkg/HelloWorld.exe .)
python3 pack.py pkg HelloWorld-unsigned.msix
if [ ! -f cert.pem ]; then
  openssl req -x509 -newkey rsa:2048 -nodes -keyout key.pem -out cert.pem -days 730 -subj "/CN=HelloWorld Dev" \
    -addext "basicConstraints=critical,CA:FALSE" -addext "keyUsage=critical,digitalSignature" \
    -addext "extendedKeyUsage=codeSigning"
  openssl x509 -in cert.pem -outform DER -out HelloWorld.cer
fi
rm -f HelloWorld.msix
osslsigncode sign -certs cert.pem -key key.pem -in HelloWorld-unsigned.msix -out HelloWorld.msix
rm -f HelloWorld-unsigned.msix
echo "Built HelloWorld.msix (trust HelloWorld.cer before installing)"
