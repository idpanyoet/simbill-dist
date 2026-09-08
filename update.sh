#!/bin/bash
# ============================================================================
#  update.sh v5 — updater SimBill (binary). Backup + rollback aman.
#  Chrome TIDAK diunduh ulang. node_modules -> backend/.
#  Add-on (WAHA/Mandiri/ACS) TIDAK disentuh default (mereka self-restart via
#  pm2/docker/systemd). Refresh add-on: SIMBILL_UPDATE_ADDONS=1 bash update.sh
#
#  v5 (8 Sep 2026) — dua penjaga, lahir dari kejadian nyata di server pelanggan:
#   * MENOLAK jalan bila service masih menjalankan kode .js lama. Skrip ini
#     hanya mengganti binary/node_modules/frontend/VERSION dan TIDAK PERNAH
#     menyentuh backend/*.js, sehingga di install .js hasilnya "berhasil" tanpa
#     mengubah apa pun — nomor versi naik, panel berganti, kode tetap lama.
#   * VERSION ditulis SETELAH service terbukti berjalan memakai binary baru.
#     Sebelumnya VERSION ditulis lebih dulu, jadi bila restart gagal panel tetap
#     mengaku "sudah terbaru" dan update berikutnya berhenti di situ selamanya.
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

# ── Apa yang SEBENARNYA dijalankan service? ─────────────────────────────────
# Dibaca dari cmdline proses, BUKAN dari nama berkas: instalasi binary pun
# sering masih menyimpan backend/server.js peninggalan lama, jadi keberadaan
# berkas itu tidak membuktikan apa-apa.
#   binary → menjalankan $HOME_DIR/simbill
#   js     → menjalankan node ... .js
#   ?      → tak bisa ditentukan (pm2 tak ada / service tak terdaftar di pm2)
jalan_apa() {
  local pid cmd
  command -v pm2 >/dev/null 2>&1 || { echo "?"; return; }
  pid=$(pm2 pid "$SVC" 2>/dev/null | tr -d ' \r\n')
  [ -n "$pid" ] && [ -r "/proc/$pid/cmdline" ] || { echo "?"; return; }
  cmd=$(tr '\0' ' ' < "/proc/$pid/cmdline")
  case "$cmd" in
    *"$HOME_DIR/simbill"*) echo "binary" ;;
    *node*|*.js*)          echo "js" ;;
    *)                     echo "?" ;;
  esac
}

SEBELUM=$(jalan_apa)
if [ "$SEBELUM" = "js" ] && [ "${SIMBILL_IZINKAN_JS:-0}" != "1" ]; then
  cat <<PESAN

==> DIHENTIKAN — instalasi ini masih menjalankan kode .js lama.

    Service '$SVC' saat ini menjalankan:
      $(tr '\0' ' ' < /proc/$(pm2 pid "$SVC" 2>/dev/null | tr -d ' \r\n')/cmdline 2>/dev/null)

    Skrip ini hanya mengganti binary, node_modules, frontend, dan VERSION.
    Ia TIDAK PERNAH menyentuh backend/*.js. Kalau diteruskan:
      - nomor versi naik dan tampilan panel berganti,
      - tetapi kode yang melayani TETAP yang lama (update yang terlihat
        berhasil padahal tidak berpengaruh sama sekali),
      - dan backend/node_modules ditimpa milik binary, sehingga fitur yang
        bergantung padanya bisa mati diam-diam.

    Yang dibutuhkan lebih dulu: pindahkan service ke binary.
      1) pastikan $HOME_DIR/.env ADA — binary tidak membaca backend/.env —
         dan JWT_SECRET di dalamnya SAMA PERSIS dengan install lama
         (kalau berbeda, semua sesi pelanggan langsung invalid)
      2) pm2 delete $SVC                 # delete, bukan stop
      3) pm2 start $HOME_DIR/simbill --name $SVC \\
             --cwd $HOME_DIR --interpreter none
      4) pm2 save
    Lalu jalankan update ini lagi.

    Lewati penjaga ini HANYA bila Anda paham akibatnya:
      SIMBILL_IZINKAN_JS=1 bash update.sh

PESAN
  exit 2
fi
[ "$SEBELUM" = "?" ] && echo "    (catatan: jenis instalasi tak bisa dipastikan — pm2 tidak ada atau service tak terdaftar)"

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

  # ── Bersihkan sampah peninggalan migrasi .js->binary (idempoten, BEBAS RISIKO).
  #    Di install fresh file2 ini tak ada -> rm dilewati (hanya kena VPS hasil
  #    migrasi). HANYA hapus yang pasti tak dipakai binary: clone git source lama,
  #    folder backup install, dan file *.bak. TIDAK menyentuh backend/database
  #    source yg mungkin dibaca saat boot.
  echo "==> Bersihkan sisa file .js lama (bila ada)..."
  rm -rf "$HOME_DIR/.git" "$HOME_DIR/_backup" 2>/dev/null || true
  rm -f "$HOME_DIR"/backend/server.js.bak* "$HOME_DIR"/backend/package-lock.json.bak \
        "$HOME_DIR"/backend/node-routeros-*.tgz 2>/dev/null || true

  # ── Restart: cari pengelola service yang benar-benar dipakai ──────────────
  if command -v pm2 >/dev/null 2>&1 && pm2 describe "$SVC" >/dev/null 2>&1; then
    pm2 restart "$SVC"
  elif systemctl list-unit-files 2>/dev/null | grep -q "^$SVC\.service"; then
    systemctl restart "$SVC"
  else
    echo
    echo "GAGAL RESTART: service '$SVC' tidak ditemukan di pm2 maupun systemd."
    echo "               Binary baru SUDAH terpasang tetapi BELUM dijalankan."
    echo "               VERSION sengaja TIDAK diubah, supaya panel tidak"
    echo "               melaporkan versi yang sebenarnya belum berjalan."
    echo "               Jalankan service-nya, lalu ulangi update ini."
    exit 4
  fi

  # ── VERSION ditulis DI SINI, sesudah restart terbukti berhasil ────────────
  sleep 2
  SESUDAH=$(jalan_apa)
  if [ "$SESUDAH" = "js" ]; then
    echo
    echo "GAGAL: sesudah restart, service MASIH menjalankan kode .js lama."
    echo "       VERSION tidak diubah. Lakukan konversi ke binary lebih dulu."
    exit 3
  fi
  [ "$NEW_VER" != "?" ] && echo "$NEW_VER" > "$HOME_DIR/VERSION"
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
