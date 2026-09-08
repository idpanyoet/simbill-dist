#!/bin/bash
# ============================================================================
#  update.sh v6 — updater SimBill (binary). Backup + rollback aman.
#  Chrome TIDAK diunduh ulang. node_modules -> backend/.
#  Add-on (WAHA/Mandiri/ACS) TIDAK disentuh default (mereka self-restart via
#  pm2/docker/systemd). Refresh add-on: SIMBILL_UPDATE_ADDONS=1 bash update.sh
#
#  v6 (8 Sep 2026) — instalasi .js lama DIKUNCI (bukan sekadar ditolak):
#   * Bila service masih menjalankan .js, panel diganti halaman 'hubungi kami
#     untuk migrasi ke SimBill Binary' dan owner menghubungi kami untuk
#     dipindahkan (spt kasus adizka). DB & RADIUS tidak disentuh; internet
#     pelanggan tetap jalan; reversibel penuh.
#  v5 — dua penjaga, lahir dari kejadian nyata di server pelanggan:
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

# ── KUNCI instalasi .js lama ────────────────────────────────────────────────
# Server yang masih menjalankan kode .js (baik yang binary-nya belum ada maupun
# yang binary-nya SUDAH terunduh tapi pm2 masih menunjuk server.js — kasus
# adizka) tidak bisa di-update dengan aman oleh skrip ini: ia hanya mengganti
# binary/frontend/VERSION, tidak pernah menyentuh backend/*.js. Daripada
# "berhasil" secara semu, panel dikunci dengan halaman migrasi supaya PEMILIK
# melihatnya dan menghubungi kami untuk dipindahkan ke SimBill Binary.
# DB & FreeRADIUS TIDAK disentuh — internet pelanggan tetap jalan.
kunci_js() {
  local port ck lock_dir lock_js
  port="$(grep -E '^PORT=' "$HOME_DIR/.env" 2>/dev/null | head -1 | cut -d= -f2 | tr -d ' \r')"
  port="${port:-3000}"
  lock_dir="$HOME_DIR/.kunci-migrasi"; lock_js="$lock_dir/kunci-server.js"
  mkdir -p "$lock_dir"

  # simpan cara service lama dijalankan, utk restore saat konversi
  pm2 describe "$SVC" > "$lock_dir/pm2-describe.txt" 2>/dev/null || true
  pm2 save >/dev/null 2>&1 || true
  cp -f "$HOME/.pm2/dump.pm2" "$lock_dir/dump.pm2.simpan" 2>/dev/null || true

  cat > "$lock_js" <<'JSEOF'
const http=require('http');
const PORT=process.env.KUNCI_PORT||3000;
const WA=(process.env.KUNCI_WA||'').replace(/[^0-9]/g,'').replace(/^0/,'62');
const HTML=`<!doctype html><html lang=id><head><meta charset=utf-8>
<meta name=viewport content="width=device-width,initial-scale=1">
<title>SimBill — Perlu Migrasi</title><style>:root{color-scheme:light dark}
body{margin:0;min-height:100vh;display:flex;align-items:center;justify-content:center;
background:#0d1117;color:#e6edf3;font:16px/1.6 -apple-system,Segoe UI,Roboto,sans-serif;padding:24px}
.k{max-width:520px;background:#161b22;border:1px solid #30363d;border-radius:16px;padding:40px;text-align:center}
.i{font-size:44px}.h{font-size:22px;font-weight:700;margin:.3em 0 .4em}p{color:#9da7b3;margin:.6em 0}
a{display:inline-block;margin-top:18px;background:#238636;color:#fff;text-decoration:none;padding:12px 22px;border-radius:10px;font-weight:600}
.v{margin-top:22px;font-size:12px;color:#6e7681}</style></head><body><div class=k>
<div class=i>🔧</div><div class=h>SimBill perlu ditingkatkan</div>
<p>Versi SimBill lama pada server ini sudah tidak didukung dan perlu dipindahkan
ke <b>SimBill Binary</b> agar aman dan berfungsi penuh.</p>
<p>Silakan hubungi kami untuk proses migrasi. <b>Layanan internet pelanggan Anda
tetap berjalan normal</b> selama proses ini.</p>
${WA?`<a href="https://wa.me/${WA}">Hubungi Kami via WhatsApp</a>`:''}
<div class=v>SimBill</div></div></body></html>`;
http.createServer((q,r)=>{r.writeHead(503,{'Content-Type':'text/html; charset=utf-8','Retry-After':'3600','Cache-Control':'no-store'});r.end(HTML);})
.listen(PORT,()=>console.log('[kunci-migrasi] halaman migrasi di :'+PORT));
JSEOF

  pm2 delete "$SVC" >/dev/null 2>&1 || true
  KUNCI_PORT="$port" KUNCI_WA="${SIMBILL_KONTAK_WA:-}" \
    pm2 start "$lock_js" --name "$SVC" >/dev/null 2>&1 || true
  pm2 save >/dev/null 2>&1 || true
  date '+%Y-%m-%d %H:%M:%S %Z' > "$lock_dir/aktif"
}

SEBELUM=$(jalan_apa)
if [ "$SEBELUM" = "js" ] && [ "${SIMBILL_JANGAN_KUNCI:-0}" != "1" ]; then
  echo
  echo "==> Instalasi ini masih menjalankan kode .js lama."
  echo "    Panel akan DIKUNCI dengan halaman migrasi. DB & RADIUS tidak disentuh,"
  echo "    internet pelanggan tetap jalan. Buka kunci = konversi ke binary."
  kunci_js
  port_c="$(grep -E '^PORT=' "$HOME_DIR/.env" 2>/dev/null | head -1 | cut -d= -f2 | tr -d ' \r')"
  sleep 1
  kode=$(curl -s -o /dev/null -w '%{http_code}' --max-time 8 "http://127.0.0.1:${port_c:-3000}/" 2>/dev/null || echo '?')
  echo "==> TERKUNCI (panel HTTP $kode = halaman migrasi). Hubungi kami untuk"
  echo "    dipindahkan ke SimBill Binary. Buka: konversi-ke-binary.sh"
  exit 5
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
