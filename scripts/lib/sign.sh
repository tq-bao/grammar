# Hàm ký app dùng chung cho scripts/install.sh và scripts/make-dmg.sh. Dùng bằng `source`.
#
# Ký bằng chứng chỉ "Grammar Local Signing" (tạo bằng scripts/create-signing-cert.sh) để quyền
# Accessibility còn nguyên sau mỗi lần cài lại. Không có chứng chỉ thì ký ad-hoc và cảnh báo.

GRAMMAR_IDENTITY_NAME="${GRAMMAR_SIGNING_IDENTITY:-Grammar Local Signing}"

# In ra mã băm của chứng chỉ ký, hoặc "-" (ad-hoc) nếu không có. Cảnh báo ghi ra stderr.
grammar_signing_identity() {
  local identity
  identity="$(security find-identity -p codesigning 2>/dev/null \
    | awk -v n="\"$GRAMMAR_IDENTITY_NAME\"" 'index($0, n) {print $2; exit}')"
  if [[ -n "$identity" ]]; then
    echo "==> Ký bằng \"$GRAMMAR_IDENTITY_NAME\"" >&2
    echo "$identity"
  else
    echo "!!  Không thấy chứng chỉ \"$GRAMMAR_IDENTITY_NAME\", ký ad-hoc." >&2
    echo "    Quyền Accessibility sẽ mất sau mỗi lần cài. Chạy scripts/create-signing-cert.sh để sửa." >&2
    echo "-"
  fi
}

# grammar_sign_app <đường dẫn .app> <identity>: ký các framework rồi ký app, sau đó kiểm tra chữ ký.
grammar_sign_app() {
  local app="$1" identity="$2" framework
  for framework in "$app"/Contents/Frameworks/*.framework; do
    [[ -e "$framework" ]] || continue
    codesign --force --sign "$identity" "$framework" >/dev/null 2>&1
  done
  codesign --force --sign "$identity" "$app" >/dev/null 2>&1
  codesign --verify --deep --strict "$app"
}
