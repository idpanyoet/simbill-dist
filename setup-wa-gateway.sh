#!/bin/bash
# ============================================================================
#  setup-wa-gateway.sh — pasang WA Gateway Mandiri (Baileys) di /opt/wa-gateway
#  Diekstrak dari update.sh SimBill (fungsi setup_wa_gateway) biar bisa
#  dijalanin sendiri buat UJI di VPS dev. Idempoten: aman diulang.
#
#  Pakai: bash setup-wa-gateway.sh
# ============================================================================
set -e
c_info(){ echo "  ..  $*"; }
c_ok(){   echo "  OK  $*"; }

WG_DIR="/opt/wa-gateway"
PM2_WG="wa-gateway"
WG_PORT="3200"

command -v pm2 >/dev/null 2>&1 || { echo "pm2 tidak ada — install dulu: npm i -g pm2"; exit 1; }

NODE_MAJOR="$(node -v 2>/dev/null | sed -E 's/^v([0-9]+).*/\1/')"
if [ -z "$NODE_MAJOR" ] || [ "$NODE_MAJOR" -lt 18 ]; then
    echo "Butuh Node >= 18 (terpasang: ${NODE_MAJOR:-?})"; exit 1
fi

MEM_MB="$(free -m 2>/dev/null | awk '/^Mem:/{print $2}')"
if [ -n "$MEM_MB" ] && [ "$MEM_MB" -lt 900 ]; then
    echo "PERINGATAN: RAM ${MEM_MB}MB < 900MB — Baileys bisa OOM. Lanjut? (Ctrl-C batal)"; sleep 3
fi

c_info "Menyiapkan WA Gateway Mandiri di ${WG_DIR} ..."
mkdir -p "$WG_DIR"

cat > "${WG_DIR}/package.json" <<'WA_PKG_EOF'
{
  "name": "simbill-wa-gateway-mandiri",
  "version": "1.0.1",
  "description": "WA Gateway mandiri (self-hosted, Baileys) untuk SimBill.",
  "type": "module",
  "main": "server.js",
  "scripts": { "start": "node server.js" },
  "dependencies": {
    "@hapi/boom": "^10.0.1",
    "@whiskeysockets/baileys": "^6.7.0",
    "express": "^4.19.2",
    "pino": "^9.0.0",
    "qrcode": "^1.5.3"
  }
}
WA_PKG_EOF

cat > "${WG_DIR}/server.js" <<'WA_SERVER_EOF'
/**
 * SimBill — WA Gateway Mandiri (self-hosted, Baileys)
 */
import { Boom } from '@hapi/boom';
import express from 'express';
import pino from 'pino';
import QRCode from 'qrcode';
import { readFileSync, rmSync } from 'fs';
import { fileURLToPath } from 'url';
import { dirname, join } from 'path';
import makeWASocket, {
  useMultiFileAuthState,
  fetchLatestBaileysVersion,
  DisconnectReason,
  Browsers,
} from '@whiskeysockets/baileys';

const __dirname = dirname(fileURLToPath(import.meta.url));

try {
  const envTxt = readFileSync(join(__dirname, '.env'), 'utf8');
  envTxt.split('\n').forEach((line) => {
    const m = line.match(/^\s*([A-Za-z0-9_]+)\s*=\s*(.*)\s*$/);
    if (m && process.env[m[1]] === undefined) {
      process.env[m[1]] = m[2].replace(/^["']|["']$/g, '');
    }
  });
} catch { /* .env tidak ada — pakai ENV / default */ }

const PORT        = parseInt(process.env.WA_PORT || '3200', 10);
const TOKEN       = process.env.WA_TOKEN || 'GANTI-TOKEN-INI';
const SESSION_DIR = process.env.WA_SESSION_DIR || join(__dirname, 'auth');

const logger = pino({ level: 'silent' });

let sock = null;
let connected = false;
let meUser = null;
let currentQR = null;
let starting = false;

async function startSocket() {
  if (starting) return;
  starting = true;
  try {
    const { state, saveCreds } = await useMultiFileAuthState(SESSION_DIR);
    const { version } = await fetchLatestBaileysVersion();

    sock = makeWASocket({
      version,
      auth: state,
      logger,
      browser: Browsers.ubuntu('SimBill'),
      markOnlineOnConnect: false,
      syncFullHistory: false,
    });

    sock.ev.on('creds.update', saveCreds);

    sock.ev.on('connection.update', async (update) => {
      const { connection, lastDisconnect, qr } = update;

      if (qr) {
        try { currentQR = await QRCode.toDataURL(qr); } catch { currentQR = null; }
        connected = false;
        console.log('[WA] QR baru dibuat — buka /qr untuk scan.');
      }

      if (connection === 'open') {
        connected = true;
        currentQR = null;
        meUser = sock.user || null;
        console.log('[WA] Tersambung sebagai', meUser?.id || '(?)');
      }

      if (connection === 'close') {
        connected = false;
        const code = (lastDisconnect?.error instanceof Boom)
          ? lastDisconnect.error.output?.statusCode
          : lastDisconnect?.error?.output?.statusCode;
        const loggedOut = code === DisconnectReason.loggedOut;
        console.log('[WA] Koneksi tertutup. code=', code, 'loggedOut=', loggedOut);

        if (loggedOut) {
          try { rmSync(SESSION_DIR, { recursive: true, force: true }); } catch {}
          meUser = null;
        }
        starting = false;
        setTimeout(() => { startSocket().catch(e => console.error('[WA] restart gagal', e)); }, 2500);
        return;
      }
    });
  } catch (e) {
    console.error('[WA] startSocket error:', e?.message || e);
    setTimeout(() => { starting = false; startSocket().catch(()=>{}); }, 5000);
    return;
  }
  starting = false;
}

function toJid(raw) {
  let n = String(raw || '').replace(/[^0-9]/g, '');
  if (!n) return null;
  if (n.startsWith('0')) n = '62' + n.slice(1);
  else if (n.startsWith('620')) n = '62' + n.slice(3);
  return n + '@s.whatsapp.net';
}

const app = express();
app.use(express.json({ limit: '2mb' }));

function checkToken(req, res, next) {
  const bearer = (req.headers.authorization || '').replace(/^Bearer\s+/i, '');
  const q = req.query.token;
  if (bearer === TOKEN || q === TOKEN) return next();
  return res.status(401).json({ error: 'Token tidak valid' });
}

app.get('/', (req, res) => {
  res.json({ service: 'simbill-wa-gateway-mandiri', connected, hasQR: !!currentQR });
});

app.get('/status', checkToken, (req, res) => {
  res.json({ connected, user: meUser?.id || null, hasQR: !!currentQR });
});

app.get('/qr.json', checkToken, (req, res) => {
  res.json({ connected, user: meUser?.id || null, hasQR: !!currentQR, qr: connected ? null : currentQR });
});

app.get('/qr', checkToken, (req, res) => {
  res.set('Content-Type', 'text/html; charset=utf-8');
  if (connected) {
    return res.send(`<!doctype html><meta charset="utf-8"><body style="font-family:sans-serif;text-align:center;padding:40px">
      <h2 style="color:#16a34a">✅ WhatsApp sudah tersambung</h2>
      <p>${meUser?.id || ''}</p></body>`);
  }
  const img = currentQR
    ? `<img src="${currentQR}" style="width:300px;height:300px">`
    : `<p>Menyiapkan QR… tunggu beberapa detik lalu halaman akan refresh.</p>`;
  res.send(`<!doctype html><meta charset="utf-8">
    <meta http-equiv="refresh" content="5">
    <body style="font-family:sans-serif;text-align:center;padding:30px">
      <h2>Scan QR — WA Gateway Mandiri</h2>
      <p>WhatsApp di HP → <b>Perangkat Tertaut</b> → <b>Tautkan Perangkat</b> → scan.</p>
      ${img}
      <p style="color:#888;font-size:12px">Halaman refresh otomatis tiap 5 detik.</p>
    </body>`);
});

app.post('/send', checkToken, async (req, res) => {
  try {
    if (!connected || !sock) return res.status(503).json({ error: 'WA belum tersambung. Scan QR dulu.' });
    const { to, message } = req.body || {};
    const jid = toJid(to);
    if (!jid) return res.status(400).json({ error: 'Nomor tujuan tidak valid' });
    if (!message || !String(message).trim()) return res.status(400).json({ error: 'Pesan kosong' });

    const sent = await sock.sendMessage(jid, { text: String(message) });
    res.json({ success: true, id: sent?.key?.id || null, to: jid });
  } catch (e) {
    console.error('[WA] send error:', e?.message || e);
    res.status(500).json({ error: 'Gagal kirim: ' + (e?.message || 'unknown') });
  }
});

app.listen(PORT, '127.0.0.1', () => {
  console.log(`[WA] Gateway mandiri jalan di http://127.0.0.1:${PORT}`);
  if (TOKEN === 'GANTI-TOKEN-INI') console.warn('[WA] ⚠️  WA_TOKEN belum diset (ENV atau .env)!');
  startSocket().catch(e => console.error('[WA] start gagal', e));
});
WA_SERVER_EOF

if [ ! -f "${WG_DIR}/.env" ]; then
    TOK="$(openssl rand -hex 48 2>/dev/null)"
    [ -z "$TOK" ] && TOK="$(head -c 48 /dev/urandom 2>/dev/null | od -An -tx1 | tr -d ' \n')"
    [ -z "$TOK" ] && TOK="simbill$(date +%s)$RANDOM"
    printf 'WA_PORT=%s\nWA_TOKEN=%s\n' "$WG_PORT" "$TOK" > "${WG_DIR}/.env"
    chmod 600 "${WG_DIR}/.env" 2>/dev/null || true
    c_ok "WA Gateway: token dibuat (${WG_DIR}/.env)"
else
    c_info "WA Gateway: .env sudah ada, token lama dipakai"
fi

c_info "npm install (Baileys) — bisa 1-3 menit..."
if ( cd "$WG_DIR" && npm install --no-audit --no-fund --no-package-lock --registry=https://registry.npmjs.org/ ); then
    c_ok "WA Gateway: dependensi siap"
else
    echo "WA Gateway: npm install GAGAL — cek koneksi/registry."; exit 1
fi

if pm2 describe "$PM2_WG" >/dev/null 2>&1; then
    ( cd "$WG_DIR" && pm2 restart "$PM2_WG" ) && c_ok "WA Gateway di-restart"
else
    ( cd "$WG_DIR" && pm2 start server.js --name "$PM2_WG" ) \
        && c_ok "WA Gateway aktif (127.0.0.1:${WG_PORT})."
fi
pm2 save >/dev/null 2>&1 || true

echo ""
echo "======================================================================"
echo " SELESAI. Token gateway (buat cek):"
grep '^WA_TOKEN=' "${WG_DIR}/.env"
echo " Cek jalan : curl -s http://127.0.0.1:3200/ ; echo"
echo " Panel     : Setting > WhatsApp > Mandiri (token kebaca otomatis dari .env)"
echo "======================================================================"
