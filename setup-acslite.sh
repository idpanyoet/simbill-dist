#!/bin/bash
# ============================================================================
#  setup-acslite.sh — pasang ACS Lite (GoACS) buat SimBill.
#  Meniru instalasi yang sudah jalan di dev/produksi:
#    - /opt/acs/acs (binary) + /opt/acs/web
#    - DB + user TERPISAH 'goacs' (BUKAN billing_radius). GoACS auto-migrate
#      tabel (devices, tasks) sendiri saat start — tak perlu import schema.
#    - /opt/acs/.env: DB_DSN=goacs:<pass>@tcp(127.0.0.1:3306)/goacs?parseTime=true
#                     API_KEY=<generate>
#    - systemd unit 'acslite' (port 7547).
#
#  Idempoten & non-fatal. Kredensial ADMIN DB (buat bikin DB/user goacs)
#  dibaca dari /opt/simbill/.env. SimBill baca API_KEY otomatis dari
#  /opt/acs/.env (routes/acslite.js) → operator tak perlu ngetik token.
#
#  Pakai:  bash setup-acslite.sh [--yes]
#  Override sumber: SIMBILL_BASE=... bash setup-acslite.sh
# ============================================================================
set -u
c_ok(){   echo -e "\033[32m✓\033[0m $1"; }
c_info(){ echo -e "\033[36mℹ\033[0m $1"; }
c_err(){  echo -e "\033[31m✗\033[0m $1"; }

REPO="idpanyoet/simbill-dist"
BASE="${SIMBILL_BASE:-https://github.com/$REPO/releases/latest/download}"
ACS_DIR="/opt/acs"
APP_DIR="${APP_DIR:-/opt/simbill}"
ACS_PORT="7547"
SVC="acslite"
GOACS_DB="goacs"
GOACS_USER="goacs"

[ "$(id -u)" = "0" ] || { c_err "Jalankan sebagai root."; exit 1; }

ARCH=$(dpkg --print-architecture 2>/dev/null || uname -m)
case "$ARCH" in
  amd64|x86_64)  ACS_BIN="acs-linux-amd64" ;;
  arm64|aarch64) ACS_BIN="acs-linux-arm64" ;;
  *) c_err "Arsitektur tak didukung: $ARCH"; exit 1 ;;
esac

# ── Kredensial ADMIN DB dari SimBill .env (buat CREATE DB/USER goacs) ───────
if [ ! -f "${APP_DIR}/.env" ] && [ ! -f "${APP_DIR}/backend/.env" ]; then
    c_info "ACS Lite dilewati: ${APP_DIR}/.env belum ada (isi DB dulu, lalu ulangi)."; exit 0
fi
set -a
[ -f "${APP_DIR}/.env" ]         && . "${APP_DIR}/.env"          2>/dev/null
[ -f "${APP_DIR}/backend/.env" ] && . "${APP_DIR}/backend/.env"  2>/dev/null
set +a
ADMIN_HOST="${DB_HOST:-127.0.0.1}"; ADMIN_PORT="${DB_PORT:-3306}"
ADMIN_USER="${DB_USER:-root}";      ADMIN_PASS="${DB_PASS:-}"
case "${ADMIN_PASS}" in ""|"GANTI"*|"ubah"*|"changeme"*)
    c_info "ACS Lite dilewati: DB_PASS di ${APP_DIR}/.env belum diisi."; exit 0;;
esac
_dbadmin(){ mysql -h"$ADMIN_HOST" -P"$ADMIN_PORT" -u"$ADMIN_USER" -p"$ADMIN_PASS" "$@"; }

# ── Unduh & pasang binary + web ────────────────────────────────────────────
mkdir -p "${ACS_DIR}"
c_info "Unduh ACS Lite (GoACS) ..."
if wget -q --show-progress "${BASE}/acslite.tar.gz" -O /tmp/acslite.tar.gz; then
    tar xzf /tmp/acslite.tar.gz -C "${ACS_DIR}" && rm -f /tmp/acslite.tar.gz
    if [ -f "${ACS_DIR}/${ACS_BIN}" ]; then
        systemctl stop "${SVC}" 2>/dev/null || true      # hindari 'Text file busy'
        cp -f "${ACS_DIR}/${ACS_BIN}" "${ACS_DIR}/acs"
        chmod +x "${ACS_DIR}/acs"
        rm -f "${ACS_DIR}/acs-linux-amd64" "${ACS_DIR}/acs-linux-arm64"
    fi
    c_ok "Binary + web ACS Lite terpasang di ${ACS_DIR}"
else
    c_err "Gagal unduh acslite.tar.gz — ACS Lite dilewati (non-fatal)."; exit 0
fi

# ── DB + user goacs (idempoten). Kalau .env lama sudah punya DSN goacs →
#    PAKAI ULANG (jangan reset password user yang sudah ada). ────────────────
DB_DSN=""
if [ -f "${ACS_DIR}/.env" ] && grep -q '^DB_DSN=goacs:' "${ACS_DIR}/.env"; then
    DB_DSN="$(grep '^DB_DSN=' "${ACS_DIR}/.env" | head -1 | cut -d= -f2-)"
    c_info "ACS Lite: DSN goacs lama dipakai ulang (user/DB sudah ada)."
else
    GOACS_PASS="$(openssl rand -hex 16 2>/dev/null || head -c16 /dev/urandom | od -An -tx1 | tr -d ' \n')"
    # Bikin DB + user goacs. Password dilewatkan aman via variabel SQL (bukan interpolasi ganda).
    if _dbadmin <<SQL 2>/tmp/acs-db.err
CREATE DATABASE IF NOT EXISTS \`${GOACS_DB}\` CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;
CREATE USER IF NOT EXISTS '${GOACS_USER}'@'localhost'   IDENTIFIED BY '${GOACS_PASS}';
CREATE USER IF NOT EXISTS '${GOACS_USER}'@'127.0.0.1'   IDENTIFIED BY '${GOACS_PASS}';
ALTER USER '${GOACS_USER}'@'localhost'   IDENTIFIED BY '${GOACS_PASS}';
ALTER USER '${GOACS_USER}'@'127.0.0.1'   IDENTIFIED BY '${GOACS_PASS}';
GRANT ALL PRIVILEGES ON \`${GOACS_DB}\`.* TO '${GOACS_USER}'@'localhost';
GRANT ALL PRIVILEGES ON \`${GOACS_DB}\`.* TO '${GOACS_USER}'@'127.0.0.1';
FLUSH PRIVILEGES;
SQL
    then
        c_ok "DB '${GOACS_DB}' + user '${GOACS_USER}' siap (GoACS auto-migrate tabel saat start)."
    else
        c_err "Gagal bikin DB/user goacs (user admin '${ADMIN_USER}' kurang privilege?). Jalankan MANUAL sbg root MySQL:"
        echo "    CREATE DATABASE IF NOT EXISTS goacs CHARACTER SET utf8mb4;"
        echo "    CREATE USER IF NOT EXISTS 'goacs'@'localhost' IDENTIFIED BY '<PASSWORD>';"
        echo "    GRANT ALL PRIVILEGES ON goacs.* TO 'goacs'@'localhost'; FLUSH PRIVILEGES;"
        echo "    lalu tulis ke /opt/acs/.env: DB_DSN=goacs:<PASSWORD>@tcp(127.0.0.1:3306)/goacs?parseTime=true"
        sed 's/^/      db-err: /' /tmp/acs-db.err 2>/dev/null | head -5
        # tetap tulis .env pakai password yg kita generate (kalau nanti user dibuat manual, samakan)
    fi
    DB_DSN="${GOACS_USER}:${GOACS_PASS}@tcp(127.0.0.1:3306)/${GOACS_DB}?parseTime=true"
fi

# ── API_KEY: pakai ulang kalau ada, else generate ──────────────────────────
API_KEY=""
if [ -f "${ACS_DIR}/.env" ] && grep -q '^API_KEY=' "${ACS_DIR}/.env"; then
    API_KEY="$(grep '^API_KEY=' "${ACS_DIR}/.env" | head -1 | cut -d= -f2-)"
fi
[ -z "$API_KEY" ] && API_KEY="$(openssl rand -hex 24 2>/dev/null || head -c24 /dev/urandom | od -An -tx1 | tr -d ' \n')"

# ── Tulis /opt/acs/.env ────────────────────────────────────────────────────
printf 'DB_DSN=%s\nAPI_KEY=%s\n' "$DB_DSN" "$API_KEY" > "${ACS_DIR}/.env"
chmod 600 "${ACS_DIR}/.env" 2>/dev/null || true
c_ok "ACS Lite .env ditulis (DB_DSN goacs + API_KEY)."

# ── systemd unit (sama persis dgn yang sudah jalan) ────────────────────────
cat > /etc/systemd/system/${SVC}.service <<'UNIT_EOF'
[Unit]
Description=ACS Lite (GoACS)
After=network.target mariadb.service

[Service]
WorkingDirectory=/opt/acs
ExecStart=/opt/acs/acs
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
UNIT_EOF

systemctl daemon-reload
systemctl enable "${SVC}" >/dev/null 2>&1 || true
systemctl restart "${SVC}"

# ── Verifikasi hidup (retry) ───────────────────────────────────────────────
CODE="000"
for i in 1 2 3 4 5 6; do
    sleep 2
    CODE="$(curl -s -o /dev/null -w '%{http_code}' "http://127.0.0.1:${ACS_PORT}/" 2>/dev/null || echo 000)"
    [ "$CODE" != "000" ] && break
done
if systemctl is-active --quiet "${SVC}"; then
    c_ok "ACS Lite aktif (127.0.0.1:${ACS_PORT}, systemd '${SVC}', HTTP ${CODE})."
    c_info "SimBill baca API_KEY otomatis dari ${ACS_DIR}/.env — tak perlu isi token di panel."
else
    c_err "ACS Lite gagal start — cek: journalctl -u ${SVC} -n 40"
fi
