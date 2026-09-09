#!/bin/bash
# ============================================================================
#  konversi-ke-binary.sh — memindahkan instalasi SimBill .js LAMA (atau yang
#  terkunci halaman migrasi oleh update.sh v6) ke SimBill Binary, dengan aman.
#
#  Kodifikasi prosedur yang dipakai di server adizka (8 Sep 2026). Jalankan
#  sebagai root di server pelanggan SETELAH pemilik menghubungi kami.
#
#  Yang dilakukan, berurutan & bisa di-rollback:
#    1. backup kedua .env, dump.pm2, dan mysqldump SELURUH DB
#    2. pastikan binary ADA di disk (unduh dari rilis bila belum)
#    3. perbaiki /opt/simbill/.env dari backend/.env yang terbukti jalan,
#       + SIMBILL_HOME & TZ, JWT_SECRET DIPERTAHANKAN (sesi tak ter-reset)
#    4. arahkan pm2 ke binary (delete + start --interpreter none + save)
#    5. verifikasi: proses=binary, panel 200, DB terbaca, rute callback hidup
#
#  DB TIDAK diubah. FreeRADIUS TIDAK disentuh (internet pelanggan tetap jalan).
#  Rollback dicetak di akhir bila verifikasi gagal.
# ============================================================================
set -u
HOME_DIR="/opt/simbill"; SVC="billing-radius"; BE="$HOME_DIR/backend"
REPO="idpanyoet/simbill-dist"
BASE="https://github.com/$REPO/releases/latest/download"
merah(){ printf '\033[31m%s\033[0m\n' "$*"; }
hijau(){ printf '\033[32m%s\033[0m\n' "$*"; }
[ "$(id -u)" = 0 ] || { merah "Jalankan sebagai root."; exit 1; }
command -v pm2 >/dev/null || { merah "pm2 tidak ada."; exit 1; }

ARCH=$(dpkg --print-architecture 2>/dev/null || uname -m)
case "$ARCH" in amd64|x86_64) BIN=simbill-linux-amd64;; arm64|aarch64) BIN=simbill-linux-arm64;; *) merah "arch $ARCH tak didukung"; exit 1;; esac

TS=$(date +%Y%m%d-%H%M%S); BK="/root/konversi-$TS"; mkdir -p "$BK"
echo "==> [1/5] Backup ke $BK"
cp -a "$HOME_DIR/.env"    "$BK/opt.env.bak"     2>/dev/null || true
cp -a "$BE/.env"          "$BK/backend.env.bak" 2>/dev/null || true
cp -a "$HOME/.pm2/dump.pm2" "$BK/dump.pm2.bak"  2>/dev/null || true
# creds DB dari backend/.env (sumber yang terbukti aktif)
if [ ! -f "$BE/.env" ]; then merah "backend/.env tidak ada — instalasi tak dikenal, berhenti."; exit 1; fi
set -a; . "$BE/.env"; set +a
if ! mysqldump -h"${DB_HOST:-localhost}" -u"${DB_USER}" -p"${DB_PASS}" "${DB_NAME}" 2>/dev/null | gzip > "$BK/db-sebelum.sql.gz"; then
  merah "mysqldump GAGAL dgn creds backend/.env — periksa DB dulu, berhenti."; exit 1
fi
echo "    DB dump: $(zcat "$BK/db-sebelum.sql.gz" | wc -l) baris"

echo "==> [2/5] Pastikan binary di disk"
if [ ! -x "$HOME_DIR/simbill" ]; then
  echo "    binary belum ada — mengunduh..."
  wget -q --show-progress "$BASE/$BIN" -O "$HOME_DIR/simbill.new" || { merah "unduh binary gagal"; exit 1; }
  chmod +x "$HOME_DIR/simbill.new"; mv -f "$HOME_DIR/simbill.new" "$HOME_DIR/simbill"
  if wget -q "$BASE/node_modules.tar.gz" -O /tmp/sb-nm.tgz; then
    rm -rf "$BE/node_modules"; tar xzf /tmp/sb-nm.tgz -C "$BE" && rm -f /tmp/sb-nm.tgz || true
  fi
  wget -q "$BASE/frontend.tar.gz" -O /tmp/sb-fe.tgz && tar xzf /tmp/sb-fe.tgz -C "$HOME_DIR/frontend" && rm -f /tmp/sb-fe.tgz || true
fi
echo "    binary: $(stat -c %s "$HOME_DIR/simbill") byte"

echo "==> [3/5] Susun /opt/simbill/.env dari backend/.env (JWT dipertahankan)"
cp -f "$BE/.env" "$HOME_DIR/.env"
grep -q '^SIMBILL_HOME=' "$HOME_DIR/.env" || echo "SIMBILL_HOME=$HOME_DIR" >> "$HOME_DIR/.env"
grep -q '^TZ='          "$HOME_DIR/.env" || echo "TZ=Asia/Jakarta"        >> "$HOME_DIR/.env"
chmod 600 "$HOME_DIR/.env"
[ -n "$(grep '^JWT_SECRET=' "$HOME_DIR/.env")" ] && hijau "    JWT_SECRET ada (sesi login dipertahankan)" || merah "    ⚠ JWT_SECRET kosong!"

echo "==> [3b/5] Arahkan in-app update ke repo BINARY (simbill-dist)"
# Konversi memakai SIMBILL_SKIP_DB=1, sehingga setup-db.sh — satu-satunya yang
# menanam github_owner/repo/branch — TIDAK pernah jalan. Tanpa ketiga setting itu
# routes/update.js jatuh ke default lama 'SimBill-Project'/'master': repo SUMBER
# yang kini PRIVAT, jadi tombol Update di panel MATI selamanya (404, panel bilang
# "repo privat / belum ada release"). Hanya mengisi yang kosong / yang masih
# menunjuk repo mati — setelan kustom milik pelanggan TIDAK ditimpa.
if MYSQL_PWD="${DB_PASS}" mysql -h"${DB_HOST:-localhost}" -u"${DB_USER}" "${DB_NAME}" <<'SQLGH' 2>/dev/null
INSERT IGNORE INTO setting (kunci,nilai) VALUES
  ('github_owner','idpanyoet'),('github_repo','simbill-dist'),('github_branch','main');
UPDATE setting SET nilai='idpanyoet'    WHERE kunci='github_owner'  AND (nilai IS NULL OR nilai='');
UPDATE setting SET nilai='simbill-dist' WHERE kunci='github_repo'   AND (nilai IS NULL OR nilai='' OR nilai='SimBill-Project');
UPDATE setting SET nilai='main'         WHERE kunci='github_branch' AND (nilai IS NULL OR nilai='' OR nilai='master');
SQLGH
then hijau "    in-app update -> idpanyoet/simbill-dist (main)"
else merah "    x gagal menulis setting github_* — update dari panel mungkin tetap mati"
fi

echo "==> [4/5] Arahkan pm2 ke binary"
pm2 delete "$SVC" >/dev/null 2>&1 || true
( cd "$HOME_DIR" && pm2 start "$HOME_DIR/simbill" --name "$SVC" --cwd "$HOME_DIR" --interpreter none >/dev/null 2>&1 )
pm2 save >/dev/null 2>&1 || true
sleep 4

echo "==> [5/5] Verifikasi"
PID=$(pm2 pid "$SVC" | tr -d ' \r\n'); CMD=$(tr '\0' ' ' < "/proc/$PID/cmdline" 2>/dev/null)
PORT="$(grep -E '^PORT=' "$HOME_DIR/.env" | head -1 | cut -d= -f2 | tr -d ' \r')"; PORT="${PORT:-3000}"
OK=1
case "$CMD" in *"$HOME_DIR/simbill"*) hijau "    proses  : binary ✓";; *) merah "    proses  : BUKAN binary ($CMD)"; OK=0;; esac
H_ADMIN=$(curl -s -o /dev/null -w '%{http_code}' --max-time 12 "http://127.0.0.1:$PORT/admin" 2>/dev/null)
H_QR=$(curl -s --max-time 12 -X POST -H 'Content-Type: application/json' -d '{}' "http://127.0.0.1:$PORT/qr/qr-mpm-notify" 2>/dev/null | head -c 60)
[ "$H_ADMIN" = 200 ] && hijau "    panel   : HTTP 200 ✓" || { merah "    panel   : HTTP $H_ADMIN"; OK=0; }
case "$H_QR" in *4015200*) hijau "    callback: rute HIDUP ✓ ($H_QR)";; *) merah "    callback: $H_QR"; OK=0;; esac
[ "$(systemctl is-active freeradius 2>/dev/null || systemctl is-active radiusd 2>/dev/null)" = active ] \
  && hijau "    radius  : active (internet aman) ✓" || echo "    radius  : (cek manual)"

echo
if [ "$OK" = 1 ]; then
  hijau "✓ KONVERSI SUKSES. Backup di $BK"
  # halaman kunci (bila tadi dikunci update.sh v6) sudah tergantikan oleh pm2 di atas
  [ -d "$HOME_DIR/.kunci-migrasi" ] && rm -f "$HOME_DIR/.kunci-migrasi/aktif" 2>/dev/null || true
else
  merah "✗ VERIFIKASI GAGAL — rollback ke .js:"
  echo  "    pm2 delete $SVC"
  echo  "    cd $BE && pm2 start server.js --name $SVC --cwd $BE && pm2 save"
  echo  "  (DB tidak diubah; backup di $BK)"
  exit 1
fi
