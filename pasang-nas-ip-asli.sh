#!/bin/bash
# pasang-nas-ip-asli.sh — FreeRADIUS: NAS-IP-Address = alamat pengirim paket yang sebenarnya.
#
# Kenapa: NAS-IP-Address dikirim router tentang dirinya sendiri. NAS terdaftar mana pun bisa mengaku
# ber-IP router lain → kunci router reseller (radgroupcheck NAS-IP-Address) bisa dilewati, dan router
# yang melaporkan IP tak terdaftar tercatat di radacct dgn IP yang CoA-nya tak punya secret.
# Ditimpa di authorize (sebelum sql) dan preacct (SESUDAH acct_unique, supaya id sesi lama tetap).
#
# Pakai:  bash pasang-nas-ip-asli.sh            → pasang + cek config (TANPA restart)
#         bash pasang-nas-ip-asli.sh --restart  → pasang + cek + restart FreeRADIUS
# Aman diulang. Cek -XC gagal → berkas dikembalikan dari cadangan.
set -u
RADDIR=/etc/freeradius/3.0/
[ -d "$RADDIR" ] || RADDIR=/etc/raddb/
SITE="${RADDIR}sites-enabled/default"
[ -f "$SITE" ] || { echo "Tak ada $SITE"; exit 1; }
CAD="/root/freeradius-default.sebelum-nasip-$(date +%Y%m%d-%H%M%S)-$$"
cp -p "$SITE" "$CAD"
python3 - "$SITE" <<'PY'
import sys, re
p = sys.argv[1]; s = open(p).read(); ubah = False
BLOK = """	if ("%{Packet-Src-IP-Address}" != "") {
		update request {
			&NAS-IP-Address := "%{Packet-Src-IP-Address}"
		}
	}
"""
if '# SIMBILL-NAS-IP-ASLI\n' not in s:
    if len(re.findall(r'^authorize \{\n', s, flags=re.M)) != 1: print('GAGAL: blok authorize tak tunggal'); sys.exit(2)
    s = re.sub(r'^authorize \{\n', 'authorize {\n\t# SIMBILL-NAS-IP-ASLI\n\t#  NAS-IP-Address = alamat pengirim sebenarnya (kunci router reseller tak bisa dipalsukan NAS lain).\n' + BLOK, s, count=1, flags=re.M)
    ubah = True
if '# SIMBILL-NAS-IP-ASLI-ACCT\n' not in s:
    i = s.find('\npreacct {\n')
    j = s.find('\n\tacct_unique\n', i) if i >= 0 else -1
    k = s.find('\n}', i) if i >= 0 else -1
    if i < 0 or j < 0 or j > k: print('GAGAL: acct_unique di preacct tak ditemukan'); sys.exit(2)
    s = s[:j] + '\n\tacct_unique\n\t# SIMBILL-NAS-IP-ASLI-ACCT\n\t#  Sesudah acct_unique: id sesi yang sedang berjalan tak berubah.\n' + BLOK + s[j + len('\n\tacct_unique\n'):]
    ubah = True
open(p, 'w').write(s)
print('diubah' if ubah else 'sudah terpasang')
PY
RC=$?
if [ $RC -ne 0 ]; then cp -p "$CAD" "$SITE"; echo "Dibatalkan, berkas dikembalikan."; exit 1; fi
if ! freeradius -XC >/tmp/simbill-nasip-xc.log 2>&1; then
  cp -p "$CAD" "$SITE"; echo "freeradius -XC GAGAL → berkas dikembalikan dari $CAD"; tail -5 /tmp/simbill-nasip-xc.log; exit 1
fi
echo "Config OK (cadangan: $CAD)"
if [ "${1:-}" = "--restart" ]; then
  systemctl restart freeradius; sleep 2
  if systemctl is-active --quiet freeradius; then echo "FreeRADIUS aktif."; else
    echo "FreeRADIUS GAGAL start → kembalikan cadangan & start ulang"; cp -p "$CAD" "$SITE"; systemctl restart freeradius; sleep 2; systemctl is-active freeradius; exit 1; fi
else
  echo "Belum di-restart. Jalankan ulang dengan --restart (atau systemctl restart freeradius) di jam sepi."
fi
