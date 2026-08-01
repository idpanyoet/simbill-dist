#!/bin/bash
# ============================================================================
#  install.sh v5 — pemasang SimBill (binary) TURNKEY dari VPS KOSONG.
#  Pelanggan:  curl -fsSL https://raw.githubusercontent.com/idpanyoet/simbill-dist/main/install.sh | bash
#
#  Sekali jalan memasang:
#     • MariaDB + DB billing_radius + schema + admin default  (setup-db.sh)
#     • SimBill binary (:3000)
#     • FreeRADIUS (:1812/1813)                                (setup-freeradius.sh)
#     • WA Mandiri (Baileys :3200)                             (setup-wa-gateway.sh)
#     • WAHA (Docker :3100)                                    (setup-waha.sh)
#     • ACS Lite (GoACS :7547)                                 (setup-acslite.sh)
#
#  setup-db.sh ngisi /opt/simbill/.env (DB creds + JWT) otomatis → SimBill
#  langsung start di pass PERTAMA (tak perlu 2-pass). Semua add-on: guarded,
#  NON-FATAL, idempoten. Opt-out per service:
#     SIMBILL_SKIP_DB=1 SIMBILL_SKIP_RADIUS=1 SIMBILL_SKIP_MANDIRI=1 \
#     SIMBILL_SKIP_WAHA=1 SIMBILL_SKIP_ACS=1
# ============================================================================
set -e

REPO="idpanyoet/simbill-dist"
BASE="${SIMBILL_BASE:-https://github.com/$REPO/releases/latest/download}"
RAW="${SIMBILL_RAW:-https://raw.githubusercontent.com/$REPO/main}"
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
mkdir -p "$HOME_DIR/backend/config" "$HOME_DIR/frontend/uploads"

# ── run_addon: ambil script dari RAW, jalankan (guarded, non-fatal) ────────
run_addon() {  # $1=file  $2=label  $3=skip
  local script="$1" label="$2" skip="$3"
  if [ "$skip" = "1" ]; then echo "==> $label dilewati (opt-out)."; return 0; fi
  echo "==> $label ..."
  if wget -q "$RAW/$script" -O "/tmp/$script"; then
    ( bash "/tmp/$script" --yes ) || echo "   ($label gagal — dilewati, non-fatal)"
    rm -f "/tmp/$script"
  else
    echo "   (gagal unduh $script — $label dilewati)"
  fi
}

# 1) BINARY
echo "==> Unduh binary..."
wget -q --show-progress "$BASE/$BIN" -O "$HOME_DIR/simbill" || { echo "GAGAL unduh binary."; exit 1; }
chmod +x "$HOME_DIR/simbill"

# 2) node_modules -> backend/node_modules
echo "==> Unduh node_modules..."
wget -q --show-progress "$BASE/node_modules.tar.gz" -O /tmp/sb-nm.tar.gz \
  && rm -rf "$HOME_DIR/backend/node_modules" \
  && tar xzf /tmp/sb-nm.tar.gz -C "$HOME_DIR/backend" && rm -f /tmp/sb-nm.tar.gz \
  || { echo "GAGAL unduh node_modules."; exit 1; }

# 3) FRONTEND
echo "==> Unduh frontend..."
wget -q "$BASE/frontend.tar.gz" -O /tmp/sb-fe.tar.gz \
  && tar xzf /tmp/sb-fe.tar.gz -C "$HOME_DIR/frontend" && rm -f /tmp/sb-fe.tar.gz
mkdir -p "$HOME_DIR/frontend/uploads"

# 4) VERSION
wget -q "$BASE/VERSION" -O "$HOME_DIR/VERSION" 2>/dev/null || true

# 5) LIBRARY Chromium (buat PDF). Portable: t64 (Ubuntu24) dulu, fallback.
echo "==> Pasang library Chromium (buat PDF invoice)..."
apt-get update -qq || true
apt-get install -y unzip \
  libxcomposite1 libxdamage1 libxfixes3 libxrandr2 libgbm1 \
  libpango-1.0-0 libcairo2 libnss3 libnspr4 libxkbcommon0 libxshmfence1 \
  libxext6 libx11-6 libxcb1 fonts-liberation 2>/dev/null || true
for b in libatk1.0-0 libatk-bridge2.0-0 libcups2 libatspi2.0-0 libasound2; do
  apt-get install -y "${b}t64" 2>/dev/null || apt-get install -y "$b" 2>/dev/null || echo "  ?? $b belum keinstall"
done

# 6) Chrome-for-Testing (amd64)
CHROME_BIN=""
if [ "$ARCH_TAG" = "amd64" ]; then
  echo "==> Unduh Chrome-for-Testing $CHROME_VER (buat PDF)..."
  mkdir -p "$HOME_DIR/chrome"
  if wget -q --show-progress \
      "https://storage.googleapis.com/chrome-for-testing-public/$CHROME_VER/linux64/chrome-linux64.zip" \
      -O /tmp/sb-chrome.zip; then
    unzip -q -o /tmp/sb-chrome.zip -d "$HOME_DIR/chrome" && rm -f /tmp/sb-chrome.zip
    chmod +x "$HOME_DIR/chrome/chrome-linux64/chrome" 2>/dev/null || true
    CHROME_BIN="$HOME_DIR/chrome/chrome-linux64/chrome"
  else
    echo "   !! Gagal unduh Chrome. PDF server-side tak jalan sampai Chrome dipasang."
  fi
else
  echo "==> arm64: pakai Chromium OS: apt-get install -y chromium (set PUPPETEER_EXECUTABLE_PATH di .env)"
fi

# 7) .env skeleton (SIMBILL_HOME/TZ/PUPPETEER). DB+JWT diisi setup-db.sh.
touch "$HOME_DIR/.env"
grep -q '^SIMBILL_HOME=' "$HOME_DIR/.env" || echo "SIMBILL_HOME=$HOME_DIR" >> "$HOME_DIR/.env"
grep -q '^TZ=' "$HOME_DIR/.env" || echo "TZ=Asia/Jakarta" >> "$HOME_DIR/.env"
if [ -n "$CHROME_BIN" ]; then
  grep -q '^PUPPETEER_EXECUTABLE_PATH=' "$HOME_DIR/.env" || echo "PUPPETEER_EXECUTABLE_PATH=$CHROME_BIN" >> "$HOME_DIR/.env"
fi
timedatectl set-timezone Asia/Jakarta 2>/dev/null || true

# 8) Cron: sinkron-hotspot + deteksi-reboot (mode binary)
echo "==> Pasang crontab (tiap 2 menit)..."
( crontab -l 2>/dev/null | grep -vE 'simbill --job|jalan-sinkron-hotspot|jalan-deteksi-reboot'
  echo "*/2 * * * * cd $HOME_DIR && ./simbill --job sinkron-hotspot >/dev/null 2>&1"
  echo "*/2 * * * * cd $HOME_DIR && ./simbill --job deteksi-reboot  >/dev/null 2>&1"
) | crontab - 2>/dev/null || echo "   (crontab gagal dipasang — set manual)"

# 9) DATABASE (MariaDB + schema + admin + isi .env) — SEBELUM start SimBill.
run_addon "setup-db.sh" "Database (MariaDB + schema + admin)" "${SIMBILL_SKIP_DB:-0}"

# ── Deteksi .env terisi (DB + JWT) ─────────────────────────────────────────
env_terisi() {
  local jwt db
  jwt="$(grep -E '^JWT_SECRET=' "$HOME_DIR/.env" 2>/dev/null | cut -d= -f2-)"
  db="$(grep -E '^DB_PASS=' "$HOME_DIR/.env" 2>/dev/null | cut -d= -f2-)"
  [ -n "$jwt" ] && [ "${#jwt}" -ge 32 ] && [ -n "$db" ] \
    && ! printf '%s' "$jwt" | grep -qiE 'ganti|changeme|contoh|example'
}

# 10) Start SimBill (pm2, binary). setup-db harusnya sudah isi .env.
cd "$HOME_DIR"
if command -v pm2 >/dev/null 2>&1; then
  if env_terisi; then
    pm2 describe "$SVC" >/dev/null 2>&1 \
      && pm2 restart "$SVC" --update-env \
      || pm2 start ./simbill --name "$SVC" --interpreter none
    pm2 save
    pm2 startup systemd -u root --hp /root >/dev/null 2>&1 || true
  else
    echo "==> .env belum lengkap (setup-db gagal?). SimBill BELUM start."
    echo "    Isi $HOME_DIR/.env (DB + JWT) lalu JALANKAN ULANG installer."
  fi
else
  echo "pm2 tak ada. Install: npm i -g pm2"
fi

# 11) Service pendamping (butuh DB yang sudah dibuat setup-db)
echo ""
echo "==> Memasang FreeRADIUS + service pendamping..."
run_addon "setup-freeradius.sh"  "FreeRADIUS (:1812/1813)"    "${SIMBILL_SKIP_RADIUS:-0}"
run_addon "setup-wa-gateway.sh"  "WA Mandiri (Baileys :3200)" "${SIMBILL_SKIP_MANDIRI:-0}"
run_addon "setup-waha.sh"        "WAHA (Docker :3100)"        "${SIMBILL_SKIP_WAHA:-0}"
run_addon "setup-acslite.sh"     "ACS Lite (GoACS :7547)"     "${SIMBILL_SKIP_ACS:-0}"

echo ""
echo "======================================================================"
echo " SELESAI."
echo "   SimBill   : pm2 logs $SVC   (harus '✅ Billing RADIUS berjalan')"
echo "   Panel     : http://\$(hostname -I | awk '{print \$1}'):3000/admin  (admin / admin123)"
echo "   FreeRADIUS: systemctl is-active freeradius ; ss -lunp | grep 1812"
echo "   WA Mandiri: curl -s http://127.0.0.1:3200/ ; echo"
echo "   WAHA      : docker ps | grep waha"
echo "   ACS Lite  : systemctl is-active acslite ; ss -ltnp | grep 7547"
echo "   ⚠ GANTI password admin (admin123) segera setelah login."
echo "======================================================================"
