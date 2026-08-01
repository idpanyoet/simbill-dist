#!/bin/bash
set -e
REPO="idpanyoet/simbill-dist"
BASE="https://github.com/$REPO/releases/latest/download"
HOME_DIR="/opt/simbill"; SVC="billing-radius"
ARCH=$(dpkg --print-architecture 2>/dev/null || uname -m)
case "$ARCH" in amd64|x86_64) BIN="simbill-linux-amd64";; arm64|aarch64) BIN="simbill-linux-arm64";; *) echo "arch?"; exit 1;; esac
NEW=$(wget -qO- "$BASE/VERSION" 2>/dev/null || echo "?")
CUR=$(cat "$HOME_DIR/VERSION" 2>/dev/null || echo "?")
echo "$CUR -> $NEW"
[ "$NEW" != "?" ] && [ "$NEW" = "$CUR" ] && { echo "sudah terbaru"; exit 0; }
wget -q --show-progress "$BASE/$BIN" -O "$HOME_DIR/simbill.new" || { echo "gagal unduh"; exit 1; }
chmod +x "$HOME_DIR/simbill.new"
wget -q "$BASE/node_modules.tar.gz" -O /tmp/nm.tgz && rm -rf "$HOME_DIR/backend/node_modules" && tar xzf /tmp/nm.tgz -C "$HOME_DIR/backend" && rm -f /tmp/nm.tgz || true
cp -f "$HOME_DIR/simbill" "$HOME_DIR/simbill.bak" 2>/dev/null || true
mv -f "$HOME_DIR/simbill.new" "$HOME_DIR/simbill"
wget -q "$BASE/frontend.tar.gz" -O /tmp/fe.tgz && tar xzf /tmp/fe.tgz -C "$HOME_DIR/frontend" && rm -f /tmp/fe.tgz || true
[ "$NEW" != "?" ] && echo "$NEW" > "$HOME_DIR/VERSION"
pm2 restart "$SVC"
echo "SELESAI ($NEW). Rollback: mv $HOME_DIR/simbill.bak $HOME_DIR/simbill && pm2 restart $SVC"
