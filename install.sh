#!/bin/bash
set -e
REPO="idpanyoet/simbill-dist"
BASE="${SIMBILL_BASE:-https://github.com/$REPO/releases/latest/download}"
HOME_DIR="/opt/simbill"
SVC="billing-radius"
CHROME_VER="127.0.6533.88"
ARCH=$(dpkg --print-architecture 2>/dev/null || uname -m)
case "$ARCH" in
  amd64|x86_64)  BIN="simbill-linux-amd64"; ARCH_TAG="amd64" ;;
  arm64|aarch64) BIN="simbill-linux-arm64"; ARCH_TAG="arm64" ;;
  *) echo "Arsitektur tak didukung: $ARCH"; exit 1 ;;
esac
echo "==> Arsitektur: $ARCH -> $BIN"
timedatectl set-timezone Asia/Jakarta 2>/dev/null || true
mkdir -p "$HOME_DIR/backend/config" "$HOME_DIR/frontend/uploads"

echo "==> Unduh binary..."
wget -q --show-progress "$BASE/$BIN" -O "$HOME_DIR/simbill" || { echo "GAGAL unduh binary."; exit 1; }
chmod +x "$HOME_DIR/simbill"

echo "==> Unduh node_modules..."
wget -q --show-progress "$BASE/node_modules.tar.gz" -O /tmp/sb-nm.tar.gz \
  && rm -rf "$HOME_DIR/backend/node_modules" \
  && tar xzf /tmp/sb-nm.tar.gz -C "$HOME_DIR/backend" && rm -f /tmp/sb-nm.tar.gz \
  || { echo "GAGAL unduh node_modules."; exit 1; }

echo "==> Unduh frontend..."
wget -q "$BASE/frontend.tar.gz" -O /tmp/sb-fe.tar.gz \
  && tar xzf /tmp/sb-fe.tar.gz -C "$HOME_DIR/frontend" && rm -f /tmp/sb-fe.tar.gz
mkdir -p "$HOME_DIR/frontend/uploads"

wget -q "$BASE/VERSION" -O "$HOME_DIR/VERSION" 2>/dev/null || true

echo "==> Pasang library Chromium..."
apt-get update -qq || true
apt-get install -y unzip \
  libxcomposite1 libxdamage1 libxfixes3 libxrandr2 libgbm1 \
  libpango-1.0-0 libcairo2 libnss3 libnspr4 libxkbcommon0 libxshmfence1 \
  libxext6 libx11-6 libxcb1 fonts-liberation 2>/dev/null || true
for b in libatk1.0-0 libatk-bridge2.0-0 libcups2 libatspi2.0-0 libasound2; do
  apt-get install -y "${b}t64" 2>/dev/null || apt-get install -y "$b" 2>/dev/null || echo "  ?? $b belum keinstall"
done

if [ "$ARCH_TAG" = "amd64" ]; then
  echo "==> Unduh Chrome-for-Testing $CHROME_VER..."
  mkdir -p "$HOME_DIR/chrome"
  if wget -q --show-progress "https://storage.googleapis.com/chrome-for-testing-public/$CHROME_VER/linux64/chrome-linux64.zip" -O /tmp/sb-chrome.zip; then
    unzip -q -o /tmp/sb-chrome.zip -d "$HOME_DIR/chrome" && rm -f /tmp/sb-chrome.zip
    chmod +x "$HOME_DIR/chrome/chrome-linux64/chrome" 2>/dev/null || true
    CHROME_BIN="$HOME_DIR/chrome/chrome-linux64/chrome"
  else
    echo "   !! Gagal unduh Chrome."
  fi
fi

if [ ! -f "$HOME_DIR/.env" ]; then
  wget -q "$BASE/env.example" -O "$HOME_DIR/.env" 2>/dev/null || touch "$HOME_DIR/.env"
  echo "==> .env dibuat — ISI DB & JWT_SECRET SEBELUM start."
fi
grep -q '^SIMBILL_HOME=' "$HOME_DIR/.env" || echo "SIMBILL_HOME=$HOME_DIR" >> "$HOME_DIR/.env"
grep -q '^TZ=' "$HOME_DIR/.env" || echo "TZ=Asia/Jakarta" >> "$HOME_DIR/.env"
if [ -n "$CHROME_BIN" ]; then
  grep -q '^PUPPETEER_EXECUTABLE_PATH=' "$HOME_DIR/.env" || echo "PUPPETEER_EXECUTABLE_PATH=$CHROME_BIN" >> "$HOME_DIR/.env"
fi

echo "==> Pasang crontab (--job tiap 2 menit)..."
( crontab -l 2>/dev/null | grep -vE 'simbill --job|jalan-sinkron-hotspot|jalan-deteksi-reboot'
  echo "*/2 * * * * cd $HOME_DIR && ./simbill --job sinkron-hotspot >/dev/null 2>&1"
  echo "*/2 * * * * cd $HOME_DIR && ./simbill --job deteksi-reboot  >/dev/null 2>&1"
) | crontab - 2>/dev/null || echo "   (crontab gagal — set manual)"

cd "$HOME_DIR"
if command -v pm2 >/dev/null 2>&1; then
  pm2 describe "$SVC" >/dev/null 2>&1 && pm2 restart "$SVC" --update-env || pm2 start ./simbill --name "$SVC" --interpreter none
  pm2 save
else
  echo "pm2 tak ada."
fi
echo "==> SELESAI. Cek: pm2 logs $SVC"
