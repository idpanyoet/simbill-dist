# SimBill — Billing ISP

Billing ISP all-in-one: manajemen pelanggan PPPoE & Hotspot, RADIUS (FreeRADIUS),
tagihan/invoice, notifikasi WhatsApp, monitoring perangkat TR-069 (ACS), reseller,
dan panel web satu halaman.

Repo ini berisi **installer.

- Pasang cepat (VPS Ubuntu kosong):
  ```bash
  curl -fsSL https://raw.githubusercontent.com/idpanyoet/simbill-dist/main/install.sh | bash
  ```
- Update: lewat panel (**Pembaruan Sistem → Update Sekarang**) atau `update.sh`.
- Login awal: `admin` / `admin123` → **ganti password setelah login.**

> ⚠️ Untuk operator produksi: uji dulu di 1 server / 1 pelanggan sebelum massal.
> `node --check` cuma cek sintaks, bukan bukti aplikasi jalan.

---

## Daftar isi
1. [Arsitektur & topologi](#1-arsitektur--topologi)
2. [Fitur](#2-fitur)
3. [Instalasi (fresh VPS, turnkey)](#3-instalasi-fresh-vps-turnkey)
4. [Update SimBill](#4-update-simbill)
5. [Migrasi/konversi dari billing lama (.js) ke binary](#5-migrasikonversi-dari-billing-lama-js-ke-binary)
6. [Add-on installer (rincian tiap script)](#6-add-on-installer-rincian-tiap-script)
7. [Struktur file & port](#7-struktur-file--port)
8. [Troubleshoot cepat](#8-troubleshoot-cepat)
9. [Keamanan](#9-keamanan)
10. [Catatan produksi](#10-catatan-produksi)

---

## 1. Arsitektur & topologi

SimBill = panel web (Node/Express, disajikan dari satu file `frontend/admin.html`)
di atas **MariaDB `billing_radius`** yang dipakai bareng **FreeRADIUS**. Router
MikroTik jadi NAS yang meng-auth pelanggan ke RADIUS; hasil sesi (accounting)
balik ke tabel `radacct` — inilah **the truth of life** status online pelanggan.

```
                        ┌───────────────────────────────────────────────┐
                        │                 VPS SimBill                    │
                        │                                                │
   Admin/Operator ──────┤  Panel Web (admin.html)  ── SimBill :3000      │
   (browser)            │        │        │                             │
                        │        │        │  in-app update ──► GitHub    │
                        │        ▼        ▼                     Releases │
                        │   MariaDB `billing_radius`  ◄── FreeRADIUS     │
                        │   (pelanggan, paket,             (:1812/1813)  │
                        │    invoice, radcheck,               ▲          │
                        │    radacct, setting)                │          │
                        │        ▲            add-on services │          │
                        │        │      ┌─────────────────────┴───────┐  │
                        │        │      │ WA Mandiri (Baileys) :3200  │  │
                        │        │      │ WAHA (Docker)        :3100  │  │
                        │        │      │ ACS Lite (GoACS)     :7547  │  │
                        │        │      └─────────────────────────────┘  │
                        └────────┼───────────────────────▲───────────────┘
                                 │ MikroTik API           │ TR-069 (CWMP)
                                 │ (8728/8729)            │
                        ┌────────▼────────┐      ┌────────┴─────────┐
                        │  Router MikroTik │      │   ONU / CPE      │
                        │  (NAS PPPoE/Hot) │      │  (redaman, dsb)  │
                        └────────┬─────────┘      └──────────────────┘
                                 │ PPPoE / Hotspot
                        ┌────────▼─────────┐
                        │    Pelanggan     │
                        └──────────────────┘
```

**Alur data inti:**
1. Operator kelola pelanggan/paket/tagihan di panel → SimBill tulis kredensial ke
   `radcheck`/`radusergroup` di `billing_radius`.
2. Pelanggan konek PPPoE/Hotspot ke MikroTik (NAS) → MikroTik tanya ke FreeRADIUS
   → FreeRADIUS auth dari `billing_radius`.
3. Sesi aktif & pemakaian tercatat ke `radacct` → panel baca ini untuk status
   online/last-seen (JANGAN bulk-UPDATE `acctstoptime`, merusak accounting).
4. SimBill kirim notifikasi (tagihan, isolir, dsb) via gateway WhatsApp.
5. ACS (TR-069) pantau perangkat pelanggan (mis. redaman ONU) di port 7547.

---

## 2. Fitur

Daftar berikut mengikuti **menu panel**. Panel punya tiga tampilan sesuai peran: **Admin** (penuh),
**Reseller**, dan **Teknisi**.

### Tampilan Admin

**Utama**
- Dashboard
- Pelanggan
- Voucher
- Invoice
- Paket Internet
- Reseller
- Tiket
- Absensi
- Stok Barang

**Gateway**
- WhatsApp
- Telegram
- Payment
- Sesi Aktif

**Jaringan**
- RADIUS / NAS
- OLT MNT
- Peta Jaringan
- Kelola ODC / ODP
- ACS TR-069
- ACS Lite Cloud
- Isolir

**Keuangan**
- Pengeluaran
- Kalkulator BHP/USO

**Laporan**
- Ringkasan
- Priode Pemasukan
- Laporan Pelanggan
- Laporan Voucher
- Net Profit

**Lainnya**
- Template Voucher
- Export/Import User
- Backup & Restore
- Pengaturan Sistem

**Admin**
- Setting
- Lisensi
- Pengguna Admin
- Log Admin

### Tampilan Reseller
- Dashboard
- Beli Voucher
- Pelanggan Saya
- Saldo & Topup
- Laporan
- Profil Saya

### Tampilan Teknisi
- Dashboard
- Tiket Gangguan
- Peta Jaringan
- Perangkat TR-069
- Absensi
- Stok Barang

### Yang menopang di belakang layar
- **RADIUS** — FreeRADIUS pakai `billing_radius`: kredensial di `radcheck`, grup
  di `radusergroup`, accounting di `radacct` (kebenaran hidup status online).
- **Paket** — tabel `paket` kolom `nama` + `tipe` (`pppoe` / `hotspot` / `keduanya`).
- **Voucher & pelanggan** berbagi namespace `radcheck` — hati-hati bentrok username
  saat import.
- **Invoice PDF** dicetak via Chrome headless.
- **Gateway WhatsApp** tiga jalur: WA Mandiri (Baileys), WAHA (Docker), dan WA-QR
  (`whatsapp-web.js`, legacy — tidak ikut di binary produksi).
- **TR-069 / ACS** — ACS Lite (GoACS) untuk telemetri CPE/ONU (mis. redaman). Data
  basi ditandai, bukan ditampilkan hijau palsu.
- **Provisioning MikroTik** via API (8728/8729).
- **Setting terpusat** (tabel `setting`): brand `app_name`, konfigurasi update
  `github_*`, token gateway, URL/API-key ACS, dll.
- **In-app update** (lihat §4) & **multi-bahasa (i18n)** di panel.

---

## 3. Instalasi (fresh VPS)

### Syarat
- **Ubuntu** 22.04 / 24.04, akses **root**.
- **RAM ≥ ~4 GB** (WAHA + Baileys butuh memori).
- CPU **x86-64-v2** kalau mau pakai **WAHA** (butuh `sharp`). VPS dengan CPU
  di-mask → WAHA crash-loop; service lain tetap jalan. Solusi: CPU host-passthrough.
- `arm64`: perlu build binary + acslite versi arm64 terpisah (belum default).

### Satu perintah
```bash
curl -fsSL https://raw.githubusercontent.com/idpanyoet/simbill-dist/main/install.sh | bash
```

Yang dilakukan installer, berurutan (semua add-on *guarded*, non-fatal, idempoten):
1. Pasang **Node 20 + pm2** (kalau belum ada).
2. Unduh **binary** + `node_modules` produksi + frontend + Chrome ke `/opt/simbill`.
3. **`setup-db`** — pasang MariaDB, bikin DB `billing_radius` + user, import schema,
   seed admin (`admin/admin123`), tulis `/opt/simbill/.env` (DB + JWT digenerate),
   seed setting update (`github_*` → `idpanyoet/simbill-dist/main`) + brand
   `app_name=SimBill`.
4. **Start SimBill** via pm2 (`--interpreter none`) + `pm2 startup`/`save`.
5. Add-on: **FreeRADIUS → WA Mandiri → WAHA → ACS Lite**.

### Lewati komponen tertentu (opt-out)
Set env sebelum install (mis. kalau stack tertentu sudah ada / tak diperlukan):
```bash
SIMBILL_SKIP_DB=1 SIMBILL_SKIP_RADIUS=1 SIMBILL_SKIP_MANDIRI=1 \
SIMBILL_SKIP_WAHA=1 SIMBILL_SKIP_ACS=1 \
  bash <(curl -fsSL https://raw.githubusercontent.com/idpanyoet/simbill-dist/main/install.sh)
```

### Setelah install
```bash
cat /opt/simbill/VERSION
pm2 ls | grep billing-radius
curl -s -o /dev/null -w "admin -> %{http_code}\n" http://localhost:3000/admin   # 200
```
Buka `http://IP-SERVER:3000/admin` → login `admin` / `admin123` →
**GANTI password**. Lengkapi setting (brand, gateway WA, ACS, dll) di panel.

---

## 4. Update SimBill

### A. Lewat panel (disarankan) — **Pembaruan Sistem**
Panel cek versi ke Releases repo ini, unduh binary baru, dan restart otomatis.

Repo publik. Klik **Periksa Update** lalu **Update
Sekarang**.

### B. Lewat CLI
```bash
curl -fsSL https://raw.githubusercontent.com/idpanyoet/simbill-dist/main/update.sh | bash
# ikut update add-on juga:
SIMBILL_UPDATE_ADDONS=1 bash <(curl -fsSL https://raw.githubusercontent.com/idpanyoet/simbill-dist/main/update.sh)
```

### Verifikasi update
```bash
cat /opt/simbill/VERSION            # = versi target
pm2 ls | grep billing-radius        # online
curl -s -o /dev/null -w "admin -> %{http_code}\n" http://localhost:3000/admin
```

Kalau update mentok, lihat [§8 Troubleshoot](#8-troubleshoot-cepat).

---

## 5. Migrasi/konversi dari billing lama (.js) ke Versi Sekarang

Untuk instalasi yang **sudah jalan** pakai `node server.js`. **DB & data pelanggan
TIDAK berubah — bisa rollback.** Uji di **1 pelanggan** dulu.

> Binary & `.js` pakai DB, panel, `.env` yang SAMA. Yang ditukar cuma cara jalan
> (`./simbill` vs `node server.js`). **`JWT_SECRET` WAJIB dipertahankan** supaya
> token/sesi pelanggan tetap valid.

**Ringkas:**
```bash
# 0) BACKUP dulu
mysqldump --single-transaction billing_radius > ~/billing_radius-$(date +%F).sql

# 1) Pastikan .env ada di /opt/simbill/.env (binary baca sini, BUKAN backend/.env)
[ -f /opt/simbill/.env ] || cp /opt/simbill/backend/.env /opt/simbill/.env
#   Isi minimal: SIMBILL_HOME=/opt/simbill, TZ=Asia/Jakarta,
#   DB_* (dari install lama), JWT_SECRET (dari install lama — JANGAN diganti)

# 2) Hentikan app .js lama & bebasin port 3000 (DELETE, bukan stop)
pm2 delete billing-radius && pm2 save
ss -ltnp | grep ':3000' || echo "port 3000 bebas"

# 3) Pasang binary, SKIP semua add-on (stack lama sudah ada)
SIMBILL_SKIP_DB=1 SIMBILL_SKIP_RADIUS=1 SIMBILL_SKIP_MANDIRI=1 \
SIMBILL_SKIP_WAHA=1 SIMBILL_SKIP_ACS=1 \
  bash <(curl -fsSL https://raw.githubusercontent.com/idpanyoet/simbill-dist/main/install.sh)

# 4) Karena DB di-skip, seed setting update MANUAL (biar in-app update jalan)
mysql billing_radius <<'SQL'
INSERT INTO setting (kunci,nilai) VALUES ('github_owner','idpanyoet')   ON DUPLICATE KEY UPDATE nilai=VALUES(nilai);
INSERT INTO setting (kunci,nilai) VALUES ('github_repo','simbill-dist') ON DUPLICATE KEY UPDATE nilai=VALUES(nilai);
INSERT INTO setting (kunci,nilai) VALUES ('github_branch','main')       ON DUPLICATE KEY UPDATE nilai=VALUES(nilai);
SQL

# 5) Verifikasi
pm2 ls | grep billing-radius
curl -s -o /dev/null -w "admin -> %{http_code}\n" http://localhost:3000/admin
cat /opt/simbill/VERSION
```

**Rollback (DB aman):**
```bash
pm2 delete billing-radius
cd /opt/simbill && pm2 start backend/server.js --name billing-radius   # sesuaikan cara start lama
pm2 save
```

**Jebakan konversi:**
- `JWT_SECRET` beda → semua sesi/login pelanggan invalid.
- **WA-QR (`whatsapp-web.js`) mati** di binary (sengaja dibuang) → pindah ke WAHA
  atau WA Mandiri.
- DB `billing_radius` yang sudah ada TIDAK ditimpa (`setup-db` SKIP kalau tabel
  `admin` ada) — tapi di konversi kita SKIP DB total, jadi aman.
- `TZ=Asia/Jakarta` wajib.

---

## 6. Add-on installer (rincian tiap script)

| Script | Fungsi | Port/Service |
|---|---|---|
| `install.sh` | Orkestrator turnkey (Node+pm2 → binary → setup-db → start → add-on) | — |
| `setup-db.sh` | MariaDB + DB `billing_radius` + schema + admin + `.env` + seed setting | MariaDB :3306 |
| `setup-freeradius.sh` | FreeRADIUS + modul `sql` → `billing_radius`, verifikasi `freeradius -XC` | :1812/1813 |
| `setup-wa-gateway.sh` | Gateway **WA Mandiri** (Baileys) di `/opt/wa-gateway` | :3200 |
| `setup-waha.sh` | **WAHA** via Docker, tulis token ke DB | :3100 |
| `setup-acslite.sh` | **ACS Lite (GoACS)** + DB/user `goacs` terpisah + systemd `acslite` | :7547 |
| `update.sh` | Update binary SimBill (opsi `SIMBILL_UPDATE_ADDONS=1`) | — |

Semua script apt sudah non-interaktif (`NEEDRESTART_SUSPEND=1`,
`DEBIAN_FRONTEND=noninteractive`) supaya tak nyangkut minta input.

---

## 7. Struktur file & port

**Layout `/opt/simbill` (binary):**
```
/opt/simbill/
├── simbill                 # binary (Node SEA)
├── VERSION                 # versi terpasang (dibaca in-app update)
├── .env                    # DB creds + JWT_SECRET + SIMBILL_HOME + TZ
├── backend/
│   └── node_modules/       # dependency produksi (ikut puppeteer; tanpa whatsapp-web.js)
└── frontend/
    ├── admin.html          # panel (rilis: versi minified)
    └── uploads/            # aset upload (TIDAK ditimpa saat update)
```
Add-on lain: `/opt/wa-gateway` (WA Mandiri), `/opt/acs` (`.env` ACS Lite),
container Docker `waha`.

**Port yang dipakai:**

| Port | Service |
|---|---|
| 3000 | SimBill panel/API (pm2 `billing-radius`) |
| 3100 | WAHA (Docker) |
| 3200 | WA Mandiri gateway (Baileys) |
| 7547 | ACS Lite / TR-069 (CWMP) |
| 1812/1813 | FreeRADIUS (auth/accounting) |
| 3306 | MariaDB |
| 8728/8729 | API MikroTik (**jangan** diekspos ke internet) |

---

## 8. Troubleshoot cepat

| Gejala | Penyebab & fix |
|---|---|
| Panel **"Versi Saat Ini 0.0.0"** | Binary < 1.21.0 (bug `__dirname`). Hilang setelah update ke 1.21.0+. |
| **"Versi Terbaru —" / "belum ada release"** | Setting `github_*` kosong/salah → seed `idpanyoet/simbill-dist/main` (lihat §4). |
| **"Update lain sedang berjalan"** (409) | Lock nyangkut → `pm2 restart billing-radius`, klik Update lagi. |
| Panel bilang **"sudah terbaru"** padahal ada rilis | Release belum di-`--latest` / asset `VERSION` hilang / lag GitHub. Cek: `gh api repos/idpanyoet/simbill-dist/releases/latest --jq .tag_name`. |
| Binary **tak start** (`.env belum lengkap`) | `.env` bukan di `/opt/simbill/.env`, atau DB/JWT hilang. |
| Login pelanggan invalid semua (habis konversi) | `JWT_SECRET` beda dari install lama. |
| WAHA crash-loop `Unsupported CPU` | CPU bukan x86-64-v2 → pakai host-passthrough. |

Diagnosa awal (selalu):
```bash
cat /opt/simbill/VERSION; echo
pm2 ls | grep billing-radius
curl -s -o /dev/null -w "admin -> %{http_code}\n" http://localhost:3000/admin
mysql billing_radius -e "SELECT kunci,nilai FROM setting WHERE kunci LIKE 'github%'"
```

---

## 9. Keamanan

- **Port API MikroTik (8728/8729) JANGAN diekspos ke internet** — whitelist per-IP.
- Ganti password `admin` default segera setelah login.
- `.env` berisi DB creds + `JWT_SECRET` → `chmod 600`, jangan dibocorkan.
- Endpoint publik tidak boleh membocorkan data internal (jangan `SELECT *` /
  kirim password / kredensial).
- Backup DB berkala (`mysqldump --single-transaction billing_radius`).

---

## 10. Catatan produksi

- **Deploy ke produksi = tangan operator.** Build, rilis, dan uji boleh di dev;
  tapi restart pm2 produksi, query MariaDB produksi, dan uji perangkat asli
  dilakukan manual oleh operator.
- Uji setiap rilis di **1 server / 1 pelanggan** dulu sebelum massal.
- `radacct` = kebenaran hidup — **jangan** bulk-`UPDATE acctstoptime`. Operasi DB
  besar → batch kecil + jeda (hindari deadlock dengan FreeRADIUS).
- Zona waktu server = **`Asia/Jakarta` (WIB)**; log server biasanya UTC.

---

_SimBill — dikelola oleh idpanyoet. Panduan konversi lengkap:
`PANDUAN-KONVERSI-KE-BINARY.md`. SOP rilis: `SOP-SimBill-Binary.md`._
