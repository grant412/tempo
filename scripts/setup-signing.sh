#!/bin/zsh
# Creates a self-signed code signing identity "Tempo Dev" in the login keychain, once.
# A stable identity keeps Accessibility and Automation grants across rebuilds.
set -euo pipefail
NAME="Tempo Dev"
if security find-identity -p codesigning | grep -q "\"$NAME\""; then
  echo "identity '$NAME' already exists"; exit 0
fi
TMP=$(mktemp -d)
cat > "$TMP/cfg" <<EOF
[req]
distinguished_name=dn
x509_extensions=ext
prompt=no
[dn]
CN=$NAME
[ext]
basicConstraints=critical,CA:false
keyUsage=critical,digitalSignature
extendedKeyUsage=critical,codeSigning
EOF
openssl req -x509 -newkey rsa:2048 -nodes -keyout "$TMP/key.pem" -out "$TMP/cert.pem" -days 3650 -config "$TMP/cfg"
openssl pkcs12 -export -inkey "$TMP/key.pem" -in "$TMP/cert.pem" -out "$TMP/id.p12" -passout pass:tempo -name "$NAME"
security import "$TMP/id.p12" -k "$HOME/Library/Keychains/login.keychain-db" -P tempo -T /usr/bin/codesign
rm -rf "$TMP"
security find-identity -p codesigning | grep "$NAME"
