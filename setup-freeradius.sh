#!/bin/bash
# ============================================================================
#  setup-freeradius.sh — pasang & konfigurasi FreeRADIUS utk SimBill.
#  Diekstrak dari installer asli (proven di produksi). Arahkan modul sql ke
#  DB billing_radius, buang blok tls{} (Ubuntu 24), matikan filter_username
#  dot-separator (user@rfnet), verifikasi freeradius -XC, buka firewall.
#
#  Baca DB dari /opt/simbill/.env. Idempoten. GAGAL -XC => TIDAK enable-now
#  (biar tidak mematikan RADIUS yang mungkin sudah jalan).
#
#  Pakai: bash setup-freeradius.sh [--yes]
# ============================================================================
set -u
c_ok(){   echo -e "\033[32m✓\033[0m $1"; }
c_info(){ echo -e "\033[36mℹ\033[0m $1"; }
c_err(){  echo -e "\033[31m✗\033[0m $1"; }

# apt non-interaktif (cegah needrestart/debconf nyangkut minta input)
export DEBIAN_FRONTEND=noninteractive
export NEEDRESTART_MODE=a
export NEEDRESTART_SUSPEND=1

APP_DIR="${APP_DIR:-/opt/simbill}"
[ "$(id -u)" = "0" ] || { c_err "Jalankan sebagai root."; exit 1; }

# ── Kredensial DB dari SimBill .env ────────────────────────────────────────
if [ ! -f "${APP_DIR}/.env" ] && [ ! -f "${APP_DIR}/backend/.env" ]; then
    c_info "FreeRADIUS dilewati: ${APP_DIR}/.env belum ada (isi DB dulu, lalu ulangi)."; exit 0
fi
set -a
[ -f "${APP_DIR}/.env" ]         && . "${APP_DIR}/.env"          2>/dev/null
[ -f "${APP_DIR}/backend/.env" ] && . "${APP_DIR}/backend/.env"  2>/dev/null
set +a
DB_USER="${DB_USER:-root}"; DB_NAME="${DB_NAME:-billing_radius}"; DB_PASS="${DB_PASS:-}"
case "${DB_PASS}" in ""|"GANTI"*|"ubah"*|"changeme"*)
    c_info "FreeRADIUS dilewati: DB_PASS belum diisi di ${APP_DIR}/.env."; exit 0;;
esac

# ── Cek tabel radius ada (radcheck/radacct/nas) ────────────────────────────
if command -v mysql >/dev/null 2>&1; then
    HAS=$(mysql -h"${DB_HOST:-127.0.0.1}" -P"${DB_PORT:-3306}" -u"$DB_USER" -p"$DB_PASS" "$DB_NAME" -N -e \
        "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='$DB_NAME' AND table_name IN ('radcheck','radacct','nas')" 2>/dev/null || echo 0)
    if [ "${HAS:-0}" -lt 3 ]; then
        c_info "Tabel radius (radcheck/radacct/nas) belum lengkap di '$DB_NAME'. Import schema SimBill dulu."
        c_info "  (lanjut tetap konfigurasi FreeRADIUS; RADIUS baru jalan setelah tabel ada)"
    fi
fi

# ── Install paket ──────────────────────────────────────────────────────────
c_info "Install freeradius + freeradius-mysql ..."
apt-get install -y -qq freeradius freeradius-mysql freeradius-utils >/dev/null 2>&1 \
    || { c_err "Gagal apt install freeradius. Cek koneksi/apt."; exit 1; }
systemctl stop freeradius >/dev/null 2>&1 || true

RADDIR="$(ls -d /etc/freeradius/*/ 2>/dev/null | head -1)"
SQLMOD="${RADDIR}mods-available/sql"
if [ -z "$RADDIR" ] || [ ! -f "$SQLMOD" ]; then
    c_err "Direktori config FreeRADIUS tak ditemukan."; exit 1
fi

# 1) Modul sql → DB SimBill (dialect mysql)
sed -i -E \
  -e 's|^([[:space:]]*)dialect = .*|\1dialect = "mysql"|' \
  -e 's|^([[:space:]]*)driver = "rlm_sql_null"|\1driver = "rlm_sql_mysql"|' \
  -e "s|^([[:space:]]*)#?[[:space:]]*server = \"localhost\".*|\1server = \"127.0.0.1\"|" \
  -e "s|^([[:space:]]*)#?[[:space:]]*login = \"radius\".*|\1login = \"${DB_USER}\"|" \
  -e "s|^([[:space:]]*)#?[[:space:]]*password = \"radpass\".*|\1password = \"${DB_PASS}\"|" \
  -e "s|^([[:space:]]*)radius_db = .*|\1radius_db = \"${DB_NAME}\"|" \
  -e 's|^([[:space:]]*)#?[[:space:]]*read_clients = yes|\1read_clients = yes|' \
  -e 's|^([[:space:]]*)#?[[:space:]]*client_table = .*|\1client_table = "nas"|' \
  "$SQLMOD"

# 1b) Jaring pengaman: pastikan server/login/password/radius_db ada & uncommented
python3 - "$SQLMOD" "$DB_USER" "$DB_PASS" "$DB_NAME" <<'PY'
import sys, re
f, user, pw, db = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4]
def esc(v): return v.replace('\\', '\\\\').replace('"', '\\"')
want = {'server': '127.0.0.1', 'login': user, 'password': pw, 'radius_db': db}
lines = open(f).read().splitlines()
seen, out = set(), []
for ln in lines:
    m = re.match(r'^(\s*)#?\s*(server|login|password|radius_db)\s*=\s*"[^"]*"\s*$', ln)
    if m and m.group(2) not in seen:
        k = m.group(2); seen.add(k)
        out.append('%s%s = "%s"' % (m.group(1), k, esc(want[k])))
    else:
        out.append(ln)
missing = [k for k in want if k not in seen]
if missing:
    res = []
    for ln in out:
        res.append(ln)
        if re.match(r'^\s*driver\s*=\s*"rlm_sql_mysql"', ln):
            ind = re.match(r'^(\s*)', ln).group(1)
            for k in missing:
                res.append('%s%s = "%s"' % (ind, k, esc(want[k])))
    out = res
open(f, 'w').write('\n'.join(out) + '\n')
PY

# 1c) Buang blok tls{} utuh (brace-aware) — Ubuntu 24 ca_file tak ada → sql gagal
python3 - "$SQLMOD" <<'PY'
import sys, re
f = sys.argv[1]
lines = open(f).read().splitlines()
out, skip, depth = [], False, 0
for ln in lines:
    st = ln.strip().lstrip('#').strip()
    if not skip and re.match(r'tls\s*\{', st):
        skip = True; depth = ln.count('{') - ln.count('}')
        if depth <= 0: skip = False
        continue
    if skip:
        depth += ln.count('{') - ln.count('}')
        if depth <= 0: skip = False
        continue
    out.append(ln)
open(f, 'w').write('\n'.join(out) + '\n')
PY

# 2) Aktifkan modul sql
ln -sf ../mods-available/sql "${RADDIR}mods-enabled/sql"

# 3) Aktifkan sql di sites (uncomment '#sql')
for site in "${RADDIR}sites-enabled/default" "${RADDIR}sites-enabled/inner-tunnel"; do
  [ -f "$site" ] && sed -i 's/^\([[:space:]]*\)#[[:space:]]*sql[[:space:]]*$/\1sql/' "$site"
done

# 3b) Matikan filter_username dot-separator (biar user@rfnet tak di-reject)
FILTERPOL="${RADDIR}policy.d/filter"
if [ -f "$FILTERPOL" ] && ! grep -q '#SIMBILL-OFF' "$FILTERPOL"; then
  python3 - "$FILTERPOL" <<'PYFILT'
import sys, re
f = sys.argv[1]
lines = open(f).read().splitlines()
out, i = [], 0
while i < len(lines):
    ln = lines[i]
    if re.search(r'User-Name\s*!~\s*/@.*\\\..*/', ln) and '{' in ln:
        depth = ln.count('{') - ln.count('}')
        out.append('#SIMBILL-OFF ' + ln); i += 1
        while i < len(lines) and depth > 0:
            depth += lines[i].count('{') - lines[i].count('}')
            out.append('#SIMBILL-OFF ' + lines[i]); i += 1
        continue
    out.append(ln); i += 1
open(f, 'w').write('\n'.join(out) + '\n')
PYFILT
fi

# 4) Hak akses (freerad perlu baca config berisi password DB)
chgrp -h freerad "${RADDIR}mods-enabled/sql" 2>/dev/null || true
chown freerad:freerad "$SQLMOD" 2>/dev/null || true
chmod 640 "$SQLMOD" 2>/dev/null || true

# 5) Verifikasi config → jalankan (GAGAL -XC = jangan enable-now)
if freeradius -XC >/tmp/simbill-fr-check.log 2>&1; then
  systemctl enable --now freeradius >/dev/null 2>&1 || true
  c_ok "FreeRADIUS aktif → DB '${DB_NAME}', NAS dibaca dari tabel 'nas'."
else
  systemctl enable freeradius >/dev/null 2>&1 || true
  c_err "freeradius -XC GAGAL — service TIDAK di-start (biar aman). 20 baris terakhir:"
  tail -20 /tmp/simbill-fr-check.log | sed 's/^/    /'
  c_info "Debug manual: freeradius -X"
fi

# 6) Firewall + ip_forward (RADIUS 1812/1813 + L2TP/IPSec)
sysctl -w net.ipv4.ip_forward=1 >/dev/null 2>&1 || true
echo 'net.ipv4.ip_forward=1' > /etc/sysctl.d/99-simbill.conf
if command -v ufw >/dev/null 2>&1 && ufw status 2>/dev/null | grep -qi "Status: active"; then
  for p in 1812 1813 1701 500 4500; do ufw allow ${p}/udp >/dev/null 2>&1 || true; done
  ufw allow proto esp from any >/dev/null 2>&1 || true
  c_ok "Port RADIUS/L2TP dibuka via ufw."
else
  for p in 1812 1813 1701 500 4500; do
    iptables -C INPUT -p udp --dport $p -j ACCEPT 2>/dev/null || iptables -I INPUT -p udp --dport $p -j ACCEPT
  done
  iptables -C INPUT -p esp -j ACCEPT 2>/dev/null || iptables -I INPUT -p esp -j ACCEPT
  iptables -C INPUT -i ppp+ -j ACCEPT 2>/dev/null || iptables -I INPUT -i ppp+ -j ACCEPT
  mkdir -p /etc/iptables; iptables-save > /etc/iptables/rules.v4 2>/dev/null || true
  c_ok "Port RADIUS/L2TP dibuka via iptables."
fi

c_info "Daftarkan MikroTik di panel SimBill (menu RADIUS/NAS) → tabel 'nas', lalu tes PPPoE."
c_info "Kalau VPS di belakang firewall cloud, buka juga UDP 1812/1813 di Security Group."
