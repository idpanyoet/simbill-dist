# SimBill — Installer (binary)

Repo ini hanya launcher. Aplikasi = binary di Releases.

Pasang:
  curl -fsSL https://raw.githubusercontent.com/idpanyoet/simbill-dist/main/install.sh | bash

Lalu isi /opt/simbill/.env (DB + JWT_SECRET), jalankan:
  cd /opt/simbill && pm2 start ./simbill --name billing-radius --interpreter none && pm2 save
