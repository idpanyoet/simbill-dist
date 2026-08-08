# Panduan Pasang Domain & SSL — SimBill

Dokumen ini menjelaskan cara memasang **domain/subdomain** dan **SSL (HTTPS gratis
Let's Encrypt)** untuk SimBill di server Ubuntu/Debian, memakai **Nginx** sebagai
reverse proxy ke aplikasi Node (default berjalan di `127.0.0.1:3000`).

> Contoh sepanjang dokumen memakai domain **`dash.contoh.id`**. Ganti dengan
> domain Anda. Perintah dijalankan sebagai **root** (atau diawali `sudo`).

---

## Ringkasan Alur

```
Pengguna ──HTTPS──> Nginx (port 80/443, SSL) ──proxy──> SimBill Node (127.0.0.1:3000)
```

1. Arahkan domain ke IP server (DNS A record).
2. Pasang Nginx sebagai reverse proxy.
3. Terbitkan sertifikat SSL Let's Encrypt (Certbot).
4. Aktifkan auto-renew.

---

## Prasyarat

- Server Ubuntu/Debian dengan akses root.
- SimBill sudah berjalan (cek: `curl -s -o /dev/null -w "%{http_code}\n" http://127.0.0.1:3000` → `200`).
- Domain/subdomain yang Anda kuasai.
- Port **80** dan **443** terbuka ke internet (tidak diblok firewall/ISP).

---

## Langkah 1 — Arahkan Domain ke Server (DNS)

Di panel DNS domain Anda (Cloudflare, Niagahoster, dsb), buat **A record**:

| Type | Name          | Value (isi)        | TTL   |
|------|---------------|--------------------|-------|
| A    | `dash`        | `IP_PUBLIK_SERVER` | Auto  |

- `Name = dash` → hasilnya `dash.contoh.id`. Untuk domain utama tanpa subdomain, isi `@`.
- Ganti `IP_PUBLIK_SERVER` dengan IP publik server Anda (cek: `curl -s ifconfig.me`).

> **Cloudflare:** saat menerbitkan SSL pertama kali, set kolom **Proxy status**
> ke **DNS only** (awan abu-abu). Setelah SSL jadi, boleh dinyalakan lagi
> (awan oranye) dengan SSL/TLS mode **Full (strict)**.

**Tunggu propagasi DNS** (biasanya 1–30 menit), lalu verifikasi domain sudah
menunjuk ke IP server:

```bash
dig +short dash.contoh.id          # harus keluar IP server Anda
# atau
ping -c2 dash.contoh.id
```

Jangan lanjut ke SSL sebelum ini benar — Let's Encrypt akan gagal bila domain
belum mengarah ke server.

---

## Langkah 2 — Pasang Nginx

```bash
apt update
apt install -y nginx
systemctl enable --now nginx
```

Cek Nginx hidup: buka `http://IP_PUBLIK_SERVER` di browser → muncul halaman
"Welcome to nginx".

---

## Langkah 3 — Buat Konfigurasi Reverse Proxy

Buat file konfigurasi situs:

```bash
nano /etc/nginx/sites-available/simbill
```

Isi dengan (ganti `dash.contoh.id` dan port bila perlu):

```nginx
server {
    listen 80;
    listen [::]:80;
    server_name dash.contoh.id;

    # Batas ukuran upload (foto KTP/rumah/bukti). Sesuaikan bila perlu.
    client_max_body_size 12M;

    location / {
        proxy_pass         http://127.0.0.1:3000;
        proxy_http_version 1.1;

        # Header agar aplikasi tahu host & protokol asli (penting untuk link & SSL)
        proxy_set_header Host              $host;
        proxy_set_header X-Real-IP         $remote_addr;
        proxy_set_header X-Forwarded-For   $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;

        # Dukungan WebSocket (bila dipakai)
        proxy_set_header Upgrade    $http_upgrade;
        proxy_set_header Connection "upgrade";

        proxy_read_timeout 300s;
    }
}
```

Aktifkan situs & muat ulang Nginx:

```bash
ln -sf /etc/nginx/sites-available/simbill /etc/nginx/sites-enabled/simbill
# (opsional) matikan situs default bawaan:
rm -f /etc/nginx/sites-enabled/default

nginx -t          # uji konfigurasi — harus "syntax is ok" & "test is successful"
systemctl reload nginx
```

Uji akses via HTTP (belum SSL):

```bash
curl -s -o /dev/null -w "%{http_code}\n" http://dash.contoh.id     # 200
```

---

## Langkah 4 — Terbitkan SSL (Let's Encrypt / Certbot)

Pasang Certbot + plugin Nginx:

```bash
apt install -y certbot python3-certbot-nginx
```

Terbitkan sertifikat (Certbot otomatis mengedit konfigurasi Nginx untuk HTTPS):

```bash
certbot --nginx -d dash.contoh.id
```

Saat diminta:
- **Email** → isi email aktif (untuk notifikasi kedaluwarsa).
- **Terms of Service** → `A` (Agree).
- **Redirect HTTP → HTTPS** → pilih **2 (Redirect)** agar semua akses otomatis ke HTTPS.

Bila berhasil, muncul pesan "Congratulations!" dan sertifikat tersimpan di
`/etc/letsencrypt/live/dash.contoh.id/`.

Uji HTTPS:

```bash
curl -s -o /dev/null -w "%{http_code}\n" https://dash.contoh.id    # 200
```

Buka `https://dash.contoh.id` di browser → gembok hijau muncul. Selesai. ✅

> **Beberapa subdomain sekaligus** (mis. panel + portal):
> ```bash
> certbot --nginx -d dash.contoh.id -d portal.contoh.id
> ```
> Pastikan setiap subdomain punya A record & blok `server_name` masing-masing.

---

## Langkah 5 — Perpanjangan Otomatis (Auto-Renew)

Sertifikat Let's Encrypt berlaku **90 hari**. Certbot memasang timer otomatis.
Cek & uji:

```bash
systemctl list-timers | grep certbot          # timer aktif
certbot renew --dry-run                        # simulasi — harus "success"
```

Bila `--dry-run` sukses, perpanjangan berjalan otomatis. Tidak perlu tindakan
manual lagi.

---

## Langkah 6 — Update `app_url` di SimBill

Agar tautan (link WhatsApp, bukti, dsb) memakai domain HTTPS, set `app_url`:

- Lewat panel: **Pengaturan → Aplikasi → App URL** = `https://dash.contoh.id`.
- Atau bila ada di `.env`, sesuaikan lalu `pm2 restart billing-radius`.

---

## Verifikasi Akhir

```bash
# 1) HTTP dialihkan ke HTTPS
curl -sI http://dash.contoh.id | grep -i location        # Location: https://...

# 2) HTTPS 200
curl -s -o /dev/null -w "%{http_code}\n" https://dash.contoh.id   # 200

# 3) Sertifikat valid & tanggal kedaluwarsa
echo | openssl s_client -servername dash.contoh.id -connect dash.contoh.id:443 2>/dev/null | openssl x509 -noout -dates
```

---

## Troubleshooting

**`nginx -t` gagal / error konfigurasi**
Baca pesan error (sebutkan file & baris). Umumnya salah kurung `{}` atau titik
koma `;`. Perbaiki lalu `nginx -t` lagi.

**Certbot gagal: "Timeout / DNS problem / NXDOMAIN"**
Domain belum mengarah ke server. Cek `dig +short dash.contoh.id` = IP server.
Tunggu propagasi DNS, lalu ulangi. Pastikan port 80 terbuka (Let's Encrypt
memverifikasi lewat port 80).

**Certbot gagal saat pakai Cloudflare proxy (awan oranye)**
Set sementara ke **DNS only** (awan abu-abu) saat menerbitkan SSL, atau pakai
metode DNS challenge. Setelah jadi, nyalakan proxy dengan SSL mode **Full (strict)**.

**Buka domain muncul "502 Bad Gateway"**
Nginx jalan tapi aplikasi Node tidak. Cek:
```bash
curl -s -o /dev/null -w "%{http_code}\n" http://127.0.0.1:3000   # harus 200
pm2 status
pm2 logs billing-radius --lines 30 --nostream
```
Bila 502 hanya sesaat setelah restart, itu normal (aplikasi butuh beberapa detik
untuk siap) — tunggu ~10–15 detik.

**Upload foto gagal "413 Request Entity Too Large"**
Naikkan `client_max_body_size` di blok `server` (mis. `20M`), lalu `nginx -t &&
systemctl reload nginx`.

**Port 80/443 diblok ISP (jaringan rumah)**
Beberapa ISP memblok port 80/443 inbound. Solusi: pakai server dengan IP publik
yang portnya terbuka, atau alihkan lewat MikroTik/tunnel. Let's Encrypt HTTP
challenge butuh port 80; bila tak bisa, gunakan **DNS challenge**:
```bash
certbot certonly --manual --preferred-challenges dns -d dash.contoh.id
```

**Cek log Nginx bila ada masalah**
```bash
tail -n 50 /var/log/nginx/error.log
tail -n 50 /var/log/nginx/access.log
```

---

## Ringkasan Perintah (Cepat)

```bash
# 1) Nginx
apt update && apt install -y nginx

# 2) Konfigurasi situs (edit server_name & port di dalamnya)
nano /etc/nginx/sites-available/simbill
ln -sf /etc/nginx/sites-available/simbill /etc/nginx/sites-enabled/simbill
rm -f /etc/nginx/sites-enabled/default
nginx -t && systemctl reload nginx

# 3) SSL
apt install -y certbot python3-certbot-nginx
certbot --nginx -d dash.contoh.id

# 4) Auto-renew (uji)
certbot renew --dry-run
```

Selesai — SimBill Anda kini dapat diakses aman via `https://dash.contoh.id`. 🔒
