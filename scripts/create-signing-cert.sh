#!/usr/bin/env bash
# Tạo chứng chỉ ký code tự ký "Grammar Local Signing" trong login keychain.
#
# Vì sao: app ký ad-hoc được macOS nhận diện bằng cdhash, mà cdhash đổi sau mỗi lần build,
# nên quyền Accessibility bị mất. Ký bằng một chứng chỉ cố định thì macOS nhận diện app theo
# bundle id + chứng chỉ, và quyền còn nguyên sau mỗi lần build lại.
#
# Chạy lại nhiều lần không sao: đã có chứng chỉ thì bỏ qua.
set -euo pipefail

NAME="${GRAMMAR_SIGNING_IDENTITY:-Grammar Local Signing}"
KEYCHAIN="$HOME/Library/Keychains/login.keychain-db"

if security find-certificate -c "$NAME" "$KEYCHAIN" >/dev/null 2>&1; then
  echo "Chứng chỉ \"$NAME\" đã có trong login keychain."
  exit 0
fi

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
PASS="$(openssl rand -hex 16)"

cat > "$TMP/cert.cnf" <<EOF
[ req ]
distinguished_name = dn
x509_extensions = ext
prompt = no
[ dn ]
CN = $NAME
[ ext ]
basicConstraints = critical, CA:false
keyUsage = critical, digitalSignature
extendedKeyUsage = critical, codeSigning
subjectKeyIdentifier = hash
EOF

openssl req -x509 -newkey rsa:2048 -nodes -days 3650 \
  -keyout "$TMP/key.pem" -out "$TMP/cert.pem" -config "$TMP/cert.cnf" 2>/dev/null
openssl pkcs12 -export -inkey "$TMP/key.pem" -in "$TMP/cert.pem" \
  -name "$NAME" -out "$TMP/identity.p12" -passout "pass:$PASS"

# -T /usr/bin/codesign: cho phép codesign dùng khoá mà không hỏi mỗi lần.
security import "$TMP/identity.p12" -k "$KEYCHAIN" -P "$PASS" -T /usr/bin/codesign >/dev/null

echo "Đã tạo chứng chỉ \"$NAME\" trong login keychain (hiệu lực 10 năm)."
