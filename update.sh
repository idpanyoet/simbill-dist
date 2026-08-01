#!/bin/bash
# ============================================================================
#  update.sh v4 — updater SimBill (binary). Backup + rollback aman.
#  Chrome TIDAK diunduh ulang. node_modules -> backend/.
#  Add-on (WAHA/Mandiri/ACS) TIDAK disentuh default (mereka self-restart via
#  pm2/docker/systemd). Refresh add-on: SIMBILL_UPDATE_ADDONS=1 bash update.sh
# ============================================================================
set -e
REPO="idpanyoet/simbill-dist"
BASE="https://github.com/$REPO/releases/latest/download"
RAW="${SIMBILL_RAW:-https://raw.githubusercontent.com/$REPO/main}"
HOME_DIR="/opt/simbill"; SVC="billing-radius"

ARCH=$(dpkg --print-architecture 2>/dev/null || uname -m)
case "$ARCH" in
  amd64|x86_64)  BIN="simbill-linux-amd64" ;;
  arm64|aarch64) BIN="simbill-linux-arm64" ;;
  *) echo "Arsitektur tak didukung: $ARCH"; exit 1 ;;
esac
echo "==> Update SimBill ($ARCH)..."

NEW_VER=$(wget -qO- "$BASE/VERSION" 2>/dev/null || echo "?")
CUR_VER=$(cat "$HOME_DIR/VERSION" 2>/dev/null || echo "?")
echo "    $CUR_VER -> $NEW_VER"
[ "$NEW_VER" != "?" ] && [ "$NEW_VER" = "$CUR_VER" ] && [ "${SIMBILL_UPDATE_ADDONS:-0}" != "1" ] \
  && { echo "==> Sudah terbaru."; exit 0; }

if [ "$NEW_VER" = "?" ] || [ "$NEW_VER" != "$CUR_VER" ]; then
  wget -q --show-progress "$BASE/$BIN" -O "$HOME_DIR/simbill.new" \
    || { echo "GAGAL unduh — service TIDAK diganggu."; exit 1; }
  chmod +x "$HOME_DIR/simbill.new"

  if wget -q "$BASE/node_modules.tar.gz" -O /tmp/sb-nm.tar.gz; then
    rm -rf "$HOME_DIR/backend/node_modules"
    tar xzf /tmp/sb-nm.tar.gz -C "$HOME_DIR/backend" && rm -f /tmp/sb-nm.tar.gz || true
  fi

  cp -f "$HOME_DIR/simbill" "$HOME_DIR/simbill.bak" 2>/dev/null || true
  mv -f "$HOME_DIR/simbill.new" "$HOME_DIR/simbill"

  wget -q "$BASE/frontend.tar.gz" -O /tmp/sb-fe.tar.gz \
    && tar xzf /tmp/sb-fe.tar.gz -C "$HOME_DIR/frontend" && rm -f /tmp/sb-fe.tar.gz || true
  mkdir -p "$HOME_DIR/frontend/uploads"

  [ "$NEW_VER" != "?" ] && echo "$NEW_VER" > "$HOME_DIR/VERSION"
  pm2 restart "$SVC"
  echo "==> SimBill $NEW_VER. Rollback: mv $HOME_DIR/simbill.bak $HOME_DIR/simbill && pm2 restart $SVC"
fi

# Opsional: refresh add-on (idempoten). Default TIDAK, biar update cepat.
if [ "${SIMBILL_UPDATE_ADDONS:-0}" = "1" ]; then
  echo "==> Refresh add-on (WAHA/Mandiri/ACS)..."
  for s in setup-freeradius.sh setup-wa-gateway.sh setup-waha.sh setup-acslite.sh; do
    if wget -q "$RAW/$s" -O "/tmp/$s"; then ( bash "/tmp/$s" --yes ) || echo "   ($s dilewati)"; rm -f "/tmp/$s"; fi
  done
fi
echo "==> SELESAI."
