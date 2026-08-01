#!/usr/bin/env bash
# ============================================================================
#  SimBill — setup-waha.sh
#  Pemasangan WAHA (WhatsApp HTTP API) SEKALI JALAN:
#    - pasang Docker (bila belum ada)
#    - tarik image devlikeapro/waha
#    - jalankan container di 127.0.0.1:3100 (JANGAN 3000 = SimBill), engine NOWEB
#    - sesi persisten (/opt/waha/sessions), restart otomatis
#    - buat penanda /opt/waha/ENABLE → update.sh akan menjaga WAHA tetap hidup
#  Setelah ini: SimBill panel > Setting > WhatsApp > WAHA > Simpan, lalu Scan QR.
#
#  Pemakaian:
#    bash setup-waha.sh                 # interaktif
#    bash setup-waha.sh --yes           # tanpa konfirmasi
#    DOMAIN=dash.contoh.id WA_SECRET=xxx bash setup-waha.sh --yes   # set webhook bot
# ============================================================================
set -u
c_ok(){ echo -e "\033[32m✓\033[0m $1"; }
c_info(){ echo -e "\033[36mℹ\033[0m $1"; }
c_err(){ echo -e "\033[31m✗\033[0m $1"; }

WAHA_DIR="/opt/waha"; WAHA_NAME="waha"; WAHA_PORT="3100"; WAHA_IMG="devlikeapro/waha"
YES=0; [ "${1:-}" = "--yes" ] && YES=1
DOMAIN="${DOMAIN:-}"; WA_SECRET="${WA_SECRET:-}"

[ "$(id -u)" = "0" ] || { c_err "Jalankan sebagai root (sudo)."; exit 1; }

echo "== SimBill · Setup WAHA =="
if [ "$YES" -eq 0 ]; then
    read -r -p "Pasang & jalankan WAHA di 127.0.0.1:${WAHA_PORT}? [y/N] " a
    case "$a" in y|Y) ;; *) echo "Batal."; exit 0;; esac
fi

# 1) Docker
if ! command -v docker >/dev/null 2>&1; then
    c_info "Docker belum ada — memasang (docker.io) ..."
    if command -v apt >/dev/null 2>&1; then
        apt update -y >/dev/null 2>&1
        apt install -y docker.io >/dev/null 2>&1 || { c_err "Gagal apt install docker.io. Pasang Docker manual lalu ulangi."; exit 1; }
    else
        c_err "Bukan sistem apt. Pasang Docker manual (https://docs.docker.com/engine/install/) lalu ulangi."; exit 1
    fi
fi
systemctl enable --now docker >/dev/null 2>&1 || true
docker info >/dev/null 2>&1 || { c_err "Daemon Docker tidak jalan. Cek: systemctl status docker"; exit 1; }
c_ok "Docker siap ($(docker --version 2>/dev/null))"

# 2) Cek port 3100 bebas
if ss -ltn 2>/dev/null | grep -q ':3100 ' && ! docker ps --format '{{.Names}}' | grep -qx "$WAHA_NAME"; then
    c_err "Port ${WAHA_PORT} sudah dipakai proses lain. Bebaskan atau ubah WAHA_PORT."; exit 1
fi

# 3) Image
if ! docker image inspect "$WAHA_IMG" >/dev/null 2>&1; then
    c_info "Menarik image ${WAHA_IMG} (bisa beberapa menit) ..."
    docker pull "$WAHA_IMG" || { c_err "Gagal tarik image. Cek koneksi internet."; exit 1; }
fi
c_ok "Image WAHA siap"

# 4) Folder sesi + .env (webhook OTOMATIS dari config SimBill pelanggan)
mkdir -p "${WAHA_DIR}/sessions"

# Kalau DOMAIN/WA_SECRET tak diisi manual, baca dari config SimBill di server INI
# (app_url + wa_cmd_secret di DB) → webhook otomatis benar per-pelanggan, tanpa hardcode domain.
APP_DIR="${APP_DIR:-/opt/simbill}"
HOOK_BASE=""
if { [ -z "$DOMAIN" ] || [ -z "$WA_SECRET" ]; } && [ -f "${APP_DIR}/backend/.env" ] && command -v mysql >/dev/null 2>&1; then
    set -a; . "${APP_DIR}/backend/.env" 2>/dev/null; set +a
    _q(){ mysql -h"${DB_HOST:-127.0.0.1}" -P"${DB_PORT:-3306}" -u"${DB_USER:-root}" -p"${DB_PASS:-}" "${DB_NAME:-billing_radius}" -N -B -e "$1" 2>/dev/null; }
    APP_URL_DB="$(_q "SELECT nilai FROM setting WHERE kunci='app_url' LIMIT 1")"
    SECRET_DB="$(_q "SELECT nilai FROM setting WHERE kunci='wa_cmd_secret' LIMIT 1")"
    [ -z "$WA_SECRET" ] && WA_SECRET="$SECRET_DB"
    [ -z "$DOMAIN" ] && [ -n "$APP_URL_DB" ] && HOOK_BASE="${APP_URL_DB%/}"
fi

HOOK_ARGS=""; HU=""
if [ -n "$HOOK_BASE" ] && [ -n "$WA_SECRET" ]; then
    HU="${HOOK_BASE}/webhook/wa/waha?token=${WA_SECRET}"        # dari app_url pelanggan (sudah ada skema)
elif [ -n "$DOMAIN" ] && [ -n "$WA_SECRET" ]; then
    HU="https://${DOMAIN}/webhook/wa/waha?token=${WA_SECRET}"   # dari DOMAIN manual
fi

# 4b) API Key WAHA — generate SEKALI (idempotent), pakai di container + tulis ke
#     DB SimBill (wa_waha_token) → panel terisi OTOMATIS, pelanggan tak perlu SSH.
KEY=""
if [ -f "${WAHA_DIR}/.env" ] && grep -q '^WAHA_API_KEY=' "${WAHA_DIR}/.env"; then
    KEY="$(grep '^WAHA_API_KEY=' "${WAHA_DIR}/.env" | head -1 | cut -d= -f2-)"   # pakai ulang key lama
fi
if [ -z "$KEY" ]; then
    KEY="$(openssl rand -hex 16 2>/dev/null || head -c16 /dev/urandom | od -An -tx1 | tr -d ' \n')"
fi

# Tulis .env WAHA SEKALI (HOOK_URL bila ada + WAHA_API_KEY) — jangan saling timpa.
{ [ -n "$HU" ] && echo "HOOK_URL=${HU}"; echo "WAHA_API_KEY=${KEY}"; } > "${WAHA_DIR}/.env"

[ -n "$HU" ] && HOOK_ARGS="-e WHATSAPP_HOOK_URL=${HU} -e WHATSAPP_HOOK_EVENTS=message"
KEY_ARGS="-e WAHA_API_KEY=${KEY}"

if [ -n "$HU" ]; then
    c_ok "Webhook bot (otomatis dari config SimBill): ${HU}"
else
    c_info "Webhook bot dilewati — set 'URL Aplikasi' di Setting + Token di Bot Perintah, lalu jalankan ulang; ATAU DOMAIN=.. WA_SECRET=.. bash setup-waha.sh"
fi

# Tulis API Key + URL WAHA ke DB SimBill → panel API Key WAHA terisi otomatis.
if [ -f "${APP_DIR}/backend/.env" ] && command -v mysql >/dev/null 2>&1; then
    set -a; . "${APP_DIR}/backend/.env" 2>/dev/null; set +a
    _dbw(){ mysql -h"${DB_HOST:-127.0.0.1}" -P"${DB_PORT:-3306}" -u"${DB_USER:-root}" -p"${DB_PASS:-}" "${DB_NAME:-billing_radius}" -e "$1" 2>/dev/null; }
    if _dbw "INSERT INTO setting (kunci,nilai) VALUES ('wa_waha_token','${KEY}') ON DUPLICATE KEY UPDATE nilai=VALUES(nilai); INSERT INTO setting (kunci,nilai) VALUES ('wa_waha_url','http://127.0.0.1:${WAHA_PORT}') ON DUPLICATE KEY UPDATE nilai=VALUES(nilai); INSERT INTO setting (kunci,nilai) VALUES ('wa_waha_session','default') ON DUPLICATE KEY UPDATE nilai=VALUES(nilai);"; then
        c_ok "API Key WAHA ditulis ke SimBill — panel terisi otomatis (tak perlu generate manual)."
    else
        c_info "API Key WAHA: gagal tulis DB. Isi manual di panel (kartu WAHA > API Key): ${KEY}"
    fi
else
    c_info "API Key WAHA (simpan): ${KEY}  — isi di panel kartu WAHA bila DB tak terbaca."
fi

# 5) Jalankan / perbarui container.
#    SELALU recreate (rm + run) agar config (API key + webhook) selalu terbaru.
#    Sesi WhatsApp aman karena tersimpan di volume ${WAHA_DIR}/sessions → tak perlu scan ulang.
if docker ps -a --format '{{.Names}}' | grep -qx "$WAHA_NAME"; then
    c_info "Container '${WAHA_NAME}' sudah ada — dibuat ulang dgn config terbaru (sesi tetap aman) ..."
    docker rm -f "$WAHA_NAME" >/dev/null 2>&1 || true
fi
docker run -d --restart always --name "$WAHA_NAME" \
    -p 127.0.0.1:${WAHA_PORT}:3000 \
    -e WHATSAPP_DEFAULT_ENGINE=NOWEB \
    -v "${WAHA_DIR}/sessions:/app/.sessions" \
    ${KEY_ARGS} \
    ${HOOK_ARGS} \
    "$WAHA_IMG" >/dev/null 2>&1 || { c_err "Gagal start container. Cek: docker logs ${WAHA_NAME}"; exit 1; }

# 6) Penanda opt-in untuk update.sh
touch "${WAHA_DIR}/ENABLE"

# Tunggu WAHA siap (retry, bukan sleep buta) — perbaiki 'HTTP 000000' sebelumnya.
CODE="000"
for i in 1 2 3 4 5 6 7 8; do
    sleep 3
    CODE="$(curl -s -o /dev/null -w '%{http_code}' -H "X-Api-Key: ${KEY}" "http://127.0.0.1:${WAHA_PORT}/api/sessions" 2>/dev/null || echo 000)"
    case "$CODE" in 200|401) break;; esac
done
if [ "$CODE" = "200" ] || [ "$CODE" = "401" ]; then
    c_ok "WAHA hidup di http://127.0.0.1:${WAHA_PORT} (HTTP ${CODE})"
else
    c_info "WAHA belum merespons (HTTP ${CODE}) — tunggu ~10 detik, lalu cek ulang / docker logs ${WAHA_NAME}"
fi

echo
c_ok "Selesai. Langkah berikut:"
echo "   1) SimBill panel > Setting > WhatsApp > pilih kartu WAHA > Simpan"
echo "      (API Key kosongkan; WAHA hanya lokal. Base URL default 127.0.0.1:${WAHA_PORT}.)"
echo "   2) Klik Scan QR > scan dari WhatsApp > Perangkat Tertaut."
echo "   3) Badge berubah SCAN QR > WORKING. Test kirim dari panel."
echo "   update.sh berikutnya akan otomatis menjaga WAHA tetap berjalan."
