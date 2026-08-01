#!/bin/bash
# ============================================================================
#  setup-db.sh — MariaDB + DB billing_radius + schema + admin + isi .env.
#  Bikin SimBill bisa full-up dari VPS KOSONG (turnkey). Idempoten & non-fatal.
#
#  Alur:
#   1. Pasang MariaDB (kalau belum ada).
#   2. Kalau /opt/simbill/.env sudah punya DB yang KONEK + tabel admin ada
#      -> SKIP (konversi / sudah disiapkan).
#   3. Fresh: generate DB_PASS + JWT_SECRET, bikin DB + user, import schema
#      (unduh dari repo), seed admin (admin/admin123), tulis /opt/simbill/.env.
#
#  Pakai: bash setup-db.sh [--yes]
#  Override: DB_NAME/DB_USER (default billing_radius / simbill),
#            ADMIN_USER/ADMIN_PASS (default admin/admin123),
#            SIMBILL_RAW=... (sumber schema.sql).
# ============================================================================
set -u
c_ok(){   echo -e "\033[32m✓\033[0m $1"; }
c_info(){ echo -e "\033[36mℹ\033[0m $1"; }
c_err(){  echo -e "\033[31m✗\033[0m $1"; }

REPO="idpanyoet/simbill-dist"
RAW="${SIMBILL_RAW:-https://raw.githubusercontent.com/$REPO/main}"
APP_DIR="${APP_DIR:-/opt/simbill}"
DB_NAME="${DB_NAME:-billing_radius}"
DB_USER="${DB_USER:-simbill}"
DB_HOST="127.0.0.1"; DB_PORT="3306"
ADMIN_USER="${ADMIN_USER:-admin}"
ADMIN_PASS="${ADMIN_PASS:-admin123}"
# bcrypt(admin123, cost 10). Kalau ADMIN_PASS diubah, hash ini TIDAK cocok —
# ganti lewat panel setelah login, atau set ulang manual.
ADMIN_HASH_DEFAULT='$2b$10$nyD.xasf9KfwtQRGU6x2eedJ/A5IF.0345VWWZas3wf5r9KgIMJiO'

[ "$(id -u)" = "0" ] || { c_err "Jalankan sebagai root."; exit 1; }
mkdir -p "$APP_DIR"

# ── 1) Pasang MariaDB ──────────────────────────────────────────────────────
if ! command -v mysql >/dev/null 2>&1; then
    c_info "Pasang MariaDB ..."
    apt-get update -qq || true
    apt-get install -y -qq mariadb-server mariadb-client >/dev/null 2>&1 \
        || { c_err "Gagal apt install mariadb-server. Pasang manual lalu ulangi."; exit 1; }
fi
systemctl enable --now mariadb >/dev/null 2>&1 || service mariadb start 2>/dev/null || true
if ! mysqladmin ping >/dev/null 2>&1; then
    c_err "Daemon MariaDB tidak jalan. Cek: systemctl status mariadb"; exit 1
fi
c_ok "MariaDB siap."

# ── 2) Sudah ada DB yang konek + tabel admin? -> SKIP (idempoten/konversi) ──
_env_get(){ grep -E "^$1=" "${APP_DIR}/.env" 2>/dev/null | head -1 | cut -d= -f2-; }
E_PASS="$(_env_get DB_PASS)"; E_USER="$(_env_get DB_USER)"; E_NAME="$(_env_get DB_NAME)"
if [ -n "$E_PASS" ] && [ -n "$E_USER" ]; then
    if mysql -h127.0.0.1 -u"$E_USER" -p"$E_PASS" "${E_NAME:-$DB_NAME}" \
         -e "SELECT 1 FROM admin LIMIT 1" >/dev/null 2>&1; then
        c_ok "DB '${E_NAME:-$DB_NAME}' sudah siap + tabel admin ada — SKIP (idempoten)."
        exit 0
    fi
fi

# ── 3) Fresh setup ─────────────────────────────────────────────────────────
# Kredensial: pakai ulang dari .env kalau ada & bukan placeholder, else generate.
DB_PASS="$E_PASS"
case "$DB_PASS" in ""|"GANTI"*|"ubah"*|"changeme"*|"contoh"*)
    DB_PASS="$(openssl rand -hex 24 2>/dev/null || head -c24 /dev/urandom | od -An -tx1 | tr -d ' \n')";;
esac
[ -n "$E_USER" ] && DB_USER="$E_USER"
[ -n "$E_NAME" ] && DB_NAME="$E_NAME"

JWT_SECRET="$(_env_get JWT_SECRET)"
if [ -z "$JWT_SECRET" ] || [ "${#JWT_SECRET}" -lt 32 ] || printf '%s' "$JWT_SECRET" | grep -qiE 'ganti|changeme|contoh'; then
    JWT_SECRET="$(openssl rand -hex 48 2>/dev/null || head -c48 /dev/urandom | od -An -tx1 | tr -d ' \n')"
fi

# Bikin DB + user (root via socket di MariaDB fresh).
c_info "Bikin DB '${DB_NAME}' + user '${DB_USER}' ..."
if mysql <<SQL 2>/tmp/simbill-db.err
CREATE DATABASE IF NOT EXISTS \`${DB_NAME}\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS '${DB_USER}'@'localhost' IDENTIFIED BY '${DB_PASS}';
CREATE USER IF NOT EXISTS '${DB_USER}'@'127.0.0.1' IDENTIFIED BY '${DB_PASS}';
ALTER USER '${DB_USER}'@'localhost' IDENTIFIED BY '${DB_PASS}';
ALTER USER '${DB_USER}'@'127.0.0.1' IDENTIFIED BY '${DB_PASS}';
GRANT ALL PRIVILEGES ON \`${DB_NAME}\`.* TO '${DB_USER}'@'localhost';
GRANT ALL PRIVILEGES ON \`${DB_NAME}\`.* TO '${DB_USER}'@'127.0.0.1';
FLUSH PRIVILEGES;
SQL
then c_ok "DB + user siap."
else c_err "Gagal bikin DB/user (root MySQL perlu akses socket)."; sed 's/^/   /' /tmp/simbill-db.err | head -5; exit 1
fi

# Import schema (structure) — hanya kalau tabel 'admin' belum ada.
if mysql "${DB_NAME}" -e "SELECT 1 FROM admin LIMIT 1" >/dev/null 2>&1; then
    c_info "Schema sudah ada (tabel admin terdeteksi) — lewati import."
else
    c_info "Unduh + import schema ..."
    if wget -q "${RAW}/database/schema.sql" -O /tmp/simbill-schema.sql && [ -s /tmp/simbill-schema.sql ]; then
        if mysql "${DB_NAME}" < /tmp/simbill-schema.sql 2>/tmp/simbill-schema.err; then
            c_ok "Schema diimpor ($(grep -c 'CREATE TABLE' /tmp/simbill-schema.sql) tabel)."
        else
            c_err "Import schema GAGAL:"; sed 's/^/   /' /tmp/simbill-schema.err | head -8; exit 1
        fi
        rm -f /tmp/simbill-schema.sql
    else
        c_err "Gagal unduh schema.sql dari ${RAW}/database/schema.sql"; exit 1
    fi
fi

# Seed admin (admin/admin123) — cuma kalau belum ada admin.
CNT="$(mysql -N "${DB_NAME}" -e "SELECT COUNT(*) FROM admin" 2>/dev/null || echo 0)"
if [ "${CNT:-0}" -eq 0 ]; then
    mysql "${DB_NAME}" <<SQL 2>/dev/null \
&& c_ok "Admin default dibuat: ${ADMIN_USER} / ${ADMIN_PASS} (GANTI setelah login!)" \
|| c_info "Seed admin dilewati (cek kolom tabel admin)."
INSERT INTO admin (username, nama, email, password, role, aktif)
VALUES ('${ADMIN_USER}', 'Super Admin', 'admin@simbill.local', '${ADMIN_HASH_DEFAULT}', 'superadmin', 1);
SQL
else
    c_info "Admin sudah ada (${CNT}) — seed dilewati."
fi

# ── Tulis /opt/simbill/.env ────────────────────────────────────────────────
touch "${APP_DIR}/.env"
_set_env(){  # key value — set/replace di .env
    local k="$1" v="$2"
    if grep -qE "^${k}=" "${APP_DIR}/.env"; then
        # ganti baris (pakai | delimiter; value tak boleh mengandung |)
        sed -i "s|^${k}=.*|${k}=${v}|" "${APP_DIR}/.env"
    else
        echo "${k}=${v}" >> "${APP_DIR}/.env"
    fi
}
_set_env SIMBILL_HOME "$APP_DIR"
_set_env TZ "Asia/Jakarta"
_set_env DB_HOST "$DB_HOST"
_set_env DB_PORT "$DB_PORT"
_set_env DB_NAME "$DB_NAME"
_set_env DB_USER "$DB_USER"
_set_env DB_PASS "$DB_PASS"
_set_env JWT_SECRET "$JWT_SECRET"
chmod 600 "${APP_DIR}/.env" 2>/dev/null || true
c_ok "/opt/simbill/.env terisi (DB + JWT). SimBill siap start."
