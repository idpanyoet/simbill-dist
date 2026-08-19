#!/bin/bash
# ============================================================================
#  build.sh v3 — DI MESIN DEV (source + node_modules + internet).
#  Reproduksi langkah manual yang SUDAH terbukti end-to-end (termasuk PDF).
#  Perubahan v3: node_modules IKUT puppeteer (buat PDF); Chromium TIDAK di-bundle
#  (di-download install.sh di sisi pelanggan).
#  Jalankan dari ROOT source:  ./build.sh 1.19.1
# ============================================================================
set -e
VER="${1:?pakai: ./build.sh <versi>  (mis. ./build.sh 1.19.1)}"
[ -f backend/server.js ] || { echo "!! jalankan dari ROOT source (backend/server.js tak ketemu)"; exit 1; }
OUT="dist"; rm -rf "$OUT"; mkdir -p "$OUT"
ARCH_TAG="$(uname -m | sed 's/x86_64/amd64/; s/aarch64/arm64/')"

# BANNER: di SEA, require bawaan cuma modul built-in. Reassign ke createRequire
# berbasis DISK -> paket npm dibaca dari <SIMBILL_HOME>/backend/node_modules.
BANNER='require=(function(){const{createRequire:c}=require("node:module");const p=require("node:path");const b=process.env.SIMBILL_HOME?p.join(process.env.SIMBILL_HOME,"backend","_.js"):p.join(p.dirname(process.execPath),"backend","_.js");return c(b);})();'

echo "==> [1/5] Bundle kode backend (esbuild --packages=external + banner)"
npx --yes esbuild backend/entry.js --bundle --platform=node --target=node20 \
    --packages=external --banner:js="$BANNER" --outfile="$OUT/bundle.js"
head -c 90 "$OUT/bundle.js" | grep -q "createRequire" || { echo "!! banner TIDAK masuk — STOP"; exit 1; }
echo "    bundle: $(du -h "$OUT/bundle.js"|cut -f1)"

echo "==> [2/5] SEA -> binary ($ARCH_TAG)  (SEA tak bisa cross-compile)"
echo "{\"main\":\"$OUT/bundle.js\",\"output\":\"$OUT/sea.blob\",\"disableExperimentalSEAWarning\":true}" > "$OUT/sea.json"
node --experimental-sea-config "$OUT/sea.json"
cp "$(command -v node)" "$OUT/simbill-linux-$ARCH_TAG"
npx --yes postject "$OUT/simbill-linux-$ARCH_TAG" NODE_SEA_BLOB "$OUT/sea.blob" \
    --sentinel-fuse NODE_SEA_FUSE_fce680ab2cc467b6e072b8b5df1996b2
chmod +x "$OUT/simbill-linux-$ARCH_TAG"
rm -f "$OUT/bundle.js" "$OUT/sea.blob" "$OUT/sea.json"
echo "    binary: $(du -h "$OUT/simbill-linux-$ARCH_TAG"|cut -f1)"

echo "==> [3/5] node_modules PRODUKSI (IKUT puppeteer; buang whatsapp-web.js = QR opsional)"
if [ ! -d backend/node_modules ]; then
  ( cd backend && PUPPETEER_SKIP_DOWNLOAD=true npm install --omit=dev \
      --no-package-lock --registry=https://registry.npmjs.org/ )
fi
tar czf "$OUT/node_modules.tar.gz" -C backend \
    --exclude='node_modules/whatsapp-web.js' \
    --exclude='node_modules/.cache' \
    node_modules
echo "    node_modules.tar.gz: $(du -h "$OUT/node_modules.tar.gz"|cut -f1)"
# (OPSIONAL WA-QR) tar czf "$OUT/waqr-addon.tar.gz" -C backend node_modules/whatsapp-web.js

echo "==> [4/5] Frontend (tanpa uploads = data pelanggan)"
if [ "${MINIFY_HTML:-1}" = "1" ] && [ -f frontend/admin.html ]; then
  rm -rf "$OUT/fe"; cp -a frontend "$OUT/fe"; rm -rf "$OUT/fe/uploads"
  # minify SEMUA .html (fallback ke asli bila minify gagal / hasil kosong)
  find "$OUT/fe" -name '*.html' | while read -r h; do
    if npx --yes html-minifier-terser --collapse-whitespace --conservative-collapse \
         --remove-comments --minify-css true --minify-js true \
         "$h" -o "$h.min" 2>/dev/null && [ -s "$h.min" ]; then
      mv "$h.min" "$h"
      echo "    minify $(basename "$h") -> $(du -h "$h"|cut -f1)"
    else
      rm -f "$h.min"; echo "    !! minify gagal $(basename "$h") — pakai asli"
    fi
  done
  tar czf "$OUT/frontend.tar.gz" --exclude='uploads' -C "$OUT/fe" .
  rm -rf "$OUT/fe"
else
  tar czf "$OUT/frontend.tar.gz" --exclude='uploads' -C frontend .
fi

echo "==> [5/5] Metadata"
echo "$VER" > "$OUT/VERSION"
cp backend/.env.example "$OUT/env.example" 2>/dev/null || true

echo; echo "==> SELESAI. Isi $OUT/:"; ls -la "$OUT"
echo "==> Upload ke Releases: gh release create v$VER $OUT/* --repo <REPO> --title v$VER"
echo "!! arm64: jalankan build.sh di mesin arm64, tambahkan simbill-linux-arm64 ke rilis yg sama."
