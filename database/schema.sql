/*M!999999\- enable the sandbox mode */ 

/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8mb4 */;
/*!40103 SET @OLD_TIME_ZONE=@@TIME_ZONE */;
/*!40103 SET TIME_ZONE='+00:00' */;
/*!40014 SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0 */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;
/*!40111 SET @OLD_SQL_NOTES=@@SQL_NOTES, SQL_NOTES=0 */;
DROP TABLE IF EXISTS `absensi`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `absensi` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `karyawan_id` int(11) NOT NULL,
  `tanggal` date NOT NULL,
  `jam_masuk` time DEFAULT NULL,
  `jam_pulang` time DEFAULT NULL,
  `status` enum('hadir','terlambat','izin','cuti','sakit','alpha','libur') DEFAULT 'hadir',
  `lat_masuk` decimal(10,7) DEFAULT NULL,
  `lng_masuk` decimal(10,7) DEFAULT NULL,
  `akurasi_masuk` int(11) DEFAULT NULL,
  `lokasi_masuk` varchar(120) DEFAULT NULL,
  `dalam_geofence` tinyint(1) DEFAULT NULL,
  `lat_pulang` decimal(10,7) DEFAULT NULL,
  `lng_pulang` decimal(10,7) DEFAULT NULL,
  `face_score` decimal(5,2) DEFAULT NULL,
  `liveness_ok` tinyint(1) DEFAULT NULL,
  `foto_masuk` varchar(255) DEFAULT NULL,
  `sumber` enum('mesin','mobile','web','manual') DEFAULT 'web',
  `perangkat_id` int(11) DEFAULT NULL,
  `dibuat_offline` tinyint(1) DEFAULT 0,
  `disinkron_pada` timestamp NULL DEFAULT NULL,
  `keterangan` varchar(255) DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_kar_tgl` (`karyawan_id`,`tanggal`),
  KEY `k_tgl` (`tanggal`),
  KEY `k_status` (`status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `absensi_libur`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `absensi_libur` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `tanggal` date NOT NULL,
  `nama` varchar(150) DEFAULT NULL,
  `sumber` enum('manual','nasional') DEFAULT 'manual',
  `created_at` timestamp NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_tgl` (`tanggal`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `absensi_lokasi`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `absensi_lokasi` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `karyawan_id` int(11) NOT NULL,
  `tanggal` date NOT NULL,
  `lat` double NOT NULL,
  `lng` double NOT NULL,
  `akurasi` int(11) DEFAULT NULL,
  `waktu` timestamp NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`),
  KEY `idx_kar_tgl` (`karyawan_id`,`tanggal`),
  KEY `idx_waktu` (`waktu`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `absensi_pengajuan`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `absensi_pengajuan` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `karyawan_id` int(11) NOT NULL,
  `jenis` enum('izin','cuti','sakit','lembur') NOT NULL,
  `tgl_mulai` date NOT NULL,
  `tgl_selesai` date DEFAULT NULL,
  `jam_mulai` time DEFAULT NULL,
  `jam_selesai` time DEFAULT NULL,
  `durasi_jam` decimal(4,1) DEFAULT NULL,
  `alasan` text DEFAULT NULL,
  `lampiran` varchar(255) DEFAULT NULL,
  `status` enum('menunggu','disetujui','ditolak') DEFAULT 'menunggu',
  `disetujui_oleh` int(11) DEFAULT NULL,
  `disetujui_pada` timestamp NULL DEFAULT NULL,
  `catatan_approval` varchar(255) DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`),
  KEY `k_kar` (`karyawan_id`),
  KEY `k_status` (`status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `absensi_pengumuman`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `absensi_pengumuman` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `pesan` text NOT NULL,
  `target` varchar(60) DEFAULT 'semua',
  `channel` varchar(40) DEFAULT 'push',
  `dikirim_oleh` int(11) DEFAULT NULL,
  `jumlah_target` int(11) DEFAULT 0,
  `created_at` timestamp NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `absensi_perangkat`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `absensi_perangkat` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `nama` varchar(120) NOT NULL,
  `jenis` enum('mesin_face','mesin_fp','mobile','web','lainnya') DEFAULT 'mesin_face',
  `lokasi` varchar(120) DEFAULT NULL,
  `serial` varchar(120) DEFAULT NULL,
  `api_key` varchar(64) DEFAULT NULL,
  `status` enum('online','offline') DEFAULT 'offline',
  `terakhir_sinkron` timestamp NULL DEFAULT NULL,
  `konfig` text DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_apikey` (`api_key`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `absensi_poin`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `absensi_poin` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `karyawan_id` int(11) NOT NULL,
  `tanggal` date NOT NULL,
  `jenis` enum('ontime','terlambat','lembur','manual') DEFAULT 'manual',
  `poin` int(11) DEFAULT 0,
  `keterangan` varchar(160) DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_poin` (`karyawan_id`,`tanggal`,`jenis`),
  KEY `idx_kar_tgl` (`karyawan_id`,`tanggal`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `acs_device`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `acs_device` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `serial_number` varchar(100) NOT NULL,
  `product_class` varchar(100) DEFAULT NULL,
  `manufacturer` varchar(100) DEFAULT NULL,
  `oui` varchar(20) DEFAULT NULL,
  `software_version` varchar(50) DEFAULT NULL,
  `hardware_version` varchar(50) DEFAULT NULL,
  `ip_address` varchar(45) DEFAULT NULL,
  `mac_address` varchar(20) DEFAULT NULL,
  `connection_url` varchar(255) DEFAULT NULL,
  `pelanggan_id` int(10) unsigned DEFAULT NULL,
  `last_inform` datetime DEFAULT NULL,
  `status` enum('online','offline') DEFAULT 'offline',
  `inform_interval` int(11) DEFAULT 300,
  `param_cache` longtext DEFAULT NULL COMMENT 'JSON cache parameter device',
  `created_at` timestamp NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  PRIMARY KEY (`id`),
  UNIQUE KEY `serial_number` (`serial_number`),
  KEY `acs_pelanggan` (`pelanggan_id`),
  CONSTRAINT `acs_device_ibfk_1` FOREIGN KEY (`pelanggan_id`) REFERENCES `pelanggan` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `acs_task`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `acs_task` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `device_id` int(10) unsigned NOT NULL,
  `type` varchar(50) NOT NULL COMMENT 'SetParameterValues, Reboot, GetParameterValues',
  `params` text DEFAULT NULL COMMENT 'JSON params untuk task',
  `status` enum('pending','running','done','failed') DEFAULT 'pending',
  `result` text DEFAULT NULL,
  `created_by` varchar(50) DEFAULT 'admin',
  `created_at` timestamp NULL DEFAULT current_timestamp(),
  `done_at` datetime DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `acs_task_device` (`device_id`),
  CONSTRAINT `acs_task_ibfk_1` FOREIGN KEY (`device_id`) REFERENCES `acs_device` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `admin`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `admin` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `username` varchar(64) DEFAULT NULL,
  `nama` varchar(100) NOT NULL,
  `email` varchar(150) DEFAULT NULL,
  `password` varchar(255) NOT NULL,
  `role` enum('superadmin','admin','operator','teknisi') NOT NULL DEFAULT 'operator',
  `permissions` text DEFAULT NULL,
  `no_hp` varchar(20) DEFAULT NULL,
  `aktif` tinyint(1) NOT NULL DEFAULT 1,
  `last_login` datetime DEFAULT NULL,
  `created_at` datetime NOT NULL DEFAULT current_timestamp(),
  `updated_at` datetime DEFAULT NULL ON UPDATE current_timestamp(),
  PRIMARY KEY (`id`),
  UNIQUE KEY `username` (`username`),
  UNIQUE KEY `email` (`email`)
) ENGINE=InnoDB AUTO_INCREMENT=2 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `admin_log`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `admin_log` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `waktu` datetime NOT NULL DEFAULT current_timestamp(),
  `kategori` varchar(32) NOT NULL DEFAULT 'System',
  `pelaku` varchar(64) NOT NULL DEFAULT 'System',
  `aksi` varchar(64) NOT NULL,
  `target` varchar(128) DEFAULT NULL,
  `detail` text DEFAULT NULL,
  `ip` varchar(45) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_waktu` (`waktu`),
  KEY `idx_kategori` (`kategori`),
  KEY `idx_pelaku` (`pelaku`)
) ENGINE=InnoDB AUTO_INCREMENT=22 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `barang`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `barang` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `kode` varchar(60) DEFAULT NULL,
  `nama` varchar(160) NOT NULL,
  `kategori` varchar(60) DEFAULT NULL,
  `satuan` varchar(20) NOT NULL DEFAULT 'unit',
  `stok_min` int(11) NOT NULL DEFAULT 0,
  `harga_beli` decimal(14,2) NOT NULL DEFAULT 0.00,
  `pakai_serial` tinyint(1) NOT NULL DEFAULT 0,
  `keterangan` text DEFAULT NULL,
  `aktif` tinyint(1) NOT NULL DEFAULT 1,
  `dibuat` datetime NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_barang_kode` (`kode`),
  KEY `idx_barang_kategori` (`kategori`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `client_otp`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `client_otp` (
  `no_hp` varchar(20) NOT NULL,
  `otp` varchar(6) NOT NULL,
  `attempts` int(11) NOT NULL DEFAULT 0,
  `expired_at` datetime NOT NULL,
  `created_at` timestamp NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`no_hp`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `drop_path`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `drop_path` (
  `pelanggan_id` int(11) NOT NULL,
  `titik` text DEFAULT NULL,
  `updated_at` timestamp NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  PRIMARY KEY (`pelanggan_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `invoice`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `invoice` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `no_invoice` varchar(30) NOT NULL COMMENT 'Format: INV-YYYY-NNNN',
  `pelanggan_id` int(10) unsigned DEFAULT NULL COMMENT 'NULL untuk invoice voucher hotspot publik',
  `paket_id` int(10) unsigned NOT NULL,
  `jumlah` decimal(12,2) NOT NULL,
  `tgl_invoice` date NOT NULL,
  `tgl_jatuh_tempo` date NOT NULL,
  `tgl_bayar` datetime DEFAULT NULL,
  `metode_bayar` varchar(50) DEFAULT NULL COMMENT 'qris, va_bca, va_bri, tunai, dll',
  `payment_id` varchar(100) DEFAULT NULL COMMENT 'ID transaksi dari payment gateway',
  `payment_url` text DEFAULT NULL COMMENT 'Link pembayaran Midtrans/Xendit',
  `status` enum('unpaid','paid','overdue','cancelled') NOT NULL DEFAULT 'unpaid',
  `keterangan` text DEFAULT NULL,
  `created_at` datetime NOT NULL DEFAULT current_timestamp(),
  `updated_at` datetime NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  `dibayar_oleh` varchar(120) DEFAULT NULL,
  `dibayar_oleh_id` int(11) DEFAULT NULL,
  `dpp` decimal(15,2) DEFAULT NULL COMMENT 'Dasar Pengenaan Pajak (harga sebelum PPN)',
  `ppn_persen` decimal(5,2) DEFAULT NULL,
  `ppn_nominal` decimal(15,2) DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `no_invoice` (`no_invoice`),
  KEY `invoice_pelanggan_id` (`pelanggan_id`),
  KEY `invoice_status` (`status`),
  KEY `invoice_tgl_jatuh_tempo` (`tgl_jatuh_tempo`),
  KEY `invoice_pelanggan_status` (`pelanggan_id`,`status`),
  KEY `paket_id` (`paket_id`),
  CONSTRAINT `invoice_ibfk_1` FOREIGN KEY (`pelanggan_id`) REFERENCES `pelanggan` (`id`) ON DELETE SET NULL,
  CONSTRAINT `invoice_ibfk_2` FOREIGN KEY (`paket_id`) REFERENCES `paket` (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=2 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `kabel`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `kabel` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `nama` varchar(100) NOT NULL,
  `tipe` enum('backbone','distribusi','drop') NOT NULL DEFAULT 'distribusi',
  `titik` longtext NOT NULL,
  `keterangan` varchar(255) DEFAULT NULL,
  `dibuat_oleh` varchar(100) DEFAULT NULL,
  `created_at` datetime DEFAULT current_timestamp(),
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `karyawan`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `karyawan` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `nama` varchar(120) NOT NULL,
  `no_hp` varchar(30) DEFAULT NULL,
  `email` varchar(120) DEFAULT NULL,
  `jabatan` varchar(80) DEFAULT NULL,
  `departemen` varchar(80) DEFAULT NULL,
  `pin` varchar(32) DEFAULT NULL,
  `admin_id` int(11) DEFAULT NULL,
  `foto` varchar(255) DEFAULT NULL,
  `jam_masuk_std` time DEFAULT NULL,
  `status` enum('aktif','nonaktif') DEFAULT 'aktif',
  `created_at` timestamp NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_pin` (`pin`),
  KEY `k_status` (`status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `nas`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `nas` (
  `id` int(10) NOT NULL AUTO_INCREMENT,
  `nasname` varchar(128) NOT NULL,
  `shortname` varchar(32) DEFAULT NULL,
  `type` varchar(30) DEFAULT 'other',
  `ports` int(5) DEFAULT NULL,
  `secret` varchar(60) NOT NULL DEFAULT 'secret',
  `server` varchar(64) DEFAULT NULL,
  `community` varchar(50) DEFAULT NULL,
  `description` varchar(200) DEFAULT 'RADIUS Client',
  PRIMARY KEY (`id`),
  KEY `nas_nasname` (`nasname`)
) ENGINE=InnoDB AUTO_INCREMENT=5 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `nasreload`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `nasreload` (
  `nasipaddress` varchar(15) NOT NULL,
  `reloadtime` datetime NOT NULL,
  PRIMARY KEY (`nasipaddress`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `odc`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `odc` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `nama` varchar(64) NOT NULL,
  `olt_id` varchar(64) DEFAULT NULL,
  `latitude` decimal(10,7) DEFAULT NULL,
  `longitude` decimal(10,7) DEFAULT NULL,
  `kapasitas` int(11) DEFAULT NULL,
  `catatan` varchar(255) DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`),
  UNIQUE KEY `nama` (`nama`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `odp`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `odp` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `nama` varchar(64) NOT NULL,
  `odc_id` int(11) DEFAULT NULL,
  `latitude` decimal(10,7) DEFAULT NULL,
  `longitude` decimal(10,7) DEFAULT NULL,
  `kapasitas` int(11) DEFAULT NULL,
  `catatan` varchar(255) DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`),
  UNIQUE KEY `nama` (`nama`),
  KEY `idx_odp_odc` (`odc_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `odp_path`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `odp_path` (
  `odp_id` int(11) NOT NULL,
  `titik` text DEFAULT NULL,
  `updated_at` timestamp NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  PRIMARY KEY (`odp_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `paket`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `paket` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `nama` varchar(100) NOT NULL,
  `kecepatan_up` int(10) unsigned NOT NULL COMMENT 'Upload Mbps',
  `kecepatan_dn` int(10) unsigned NOT NULL COMMENT 'Download Mbps',
  `harga` decimal(12,2) NOT NULL,
  `harga_reseller` decimal(12,2) DEFAULT NULL COMMENT 'Harga khusus reseller (NULL = pakai komisi_persen)',
  `masa_aktif` int(11) NOT NULL DEFAULT 30 COMMENT 'nilai masa berlaku',
  `satuan_masa` enum('jam','hari','bulan') NOT NULL DEFAULT 'hari' COMMENT 'satuan masa berlaku',
  `pool_name` varchar(64) DEFAULT NULL COMMENT 'RADIUS IP Pool',
  `tipe` enum('pppoe','hotspot','keduanya') NOT NULL DEFAULT 'keduanya',
  `share_users` int(10) unsigned NOT NULL DEFAULT 1 COMMENT 'Max HP/perangkat simultan per akun (Simultaneous-Use)',
  `burst_limit` varchar(32) DEFAULT NULL COMMENT 'MikroTik burst limit',
  `burst_time` varchar(32) DEFAULT NULL COMMENT 'MikroTik burst time',
  `aktif` tinyint(1) NOT NULL DEFAULT 1,
  `deskripsi` text DEFAULT NULL,
  `created_at` datetime NOT NULL DEFAULT current_timestamp(),
  `updated_at` datetime NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  `durasi_menit` int(10) unsigned DEFAULT NULL COMMENT 'batas total uptime voucher (menit); NULL/0 = tanpa batas',
  `rate_limit` varchar(128) DEFAULT NULL,
  `izin_voucher` tinyint(1) NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=6 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `payment_log`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `payment_log` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `invoice_id` int(10) unsigned DEFAULT NULL,
  `payment_gateway` varchar(30) NOT NULL COMMENT 'midtrans, xendit, manual',
  `order_id` varchar(100) DEFAULT NULL,
  `transaction_id` varchar(100) DEFAULT NULL,
  `payment_type` varchar(50) DEFAULT NULL,
  `gross_amount` decimal(12,2) DEFAULT NULL,
  `status` varchar(30) DEFAULT NULL,
  `raw_response` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_bin DEFAULT NULL CHECK (json_valid(`raw_response`)),
  `created_at` datetime NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`),
  KEY `payment_log_invoice_id` (`invoice_id`),
  KEY `payment_log_order_id` (`order_id`),
  CONSTRAINT `payment_log_ibfk_1` FOREIGN KEY (`invoice_id`) REFERENCES `invoice` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `pelanggan`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `pelanggan` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `nama` varchar(150) NOT NULL,
  `username` varchar(64) NOT NULL COMMENT 'RADIUS username',
  `password` varchar(255) NOT NULL COMMENT 'bcrypt hash untuk login ke aplikasi (jika reseller/portal pelanggan login)',
  `radius_password_enc` varchar(255) DEFAULT NULL COMMENT 'Password RADIUS terenkripsi AES (reversible), dipulihkan saat suspend->aktif',
  `no_hp` varchar(20) NOT NULL COMMENT 'Format 628xxx untuk WA',
  `email` varchar(150) DEFAULT NULL,
  `alamat` text DEFAULT NULL,
  `paket_id` int(10) unsigned NOT NULL,
  `reseller_id` int(10) unsigned DEFAULT NULL,
  `tipe_koneksi` enum('pppoe','hotspot') NOT NULL DEFAULT 'pppoe',
  `tgl_aktif` date DEFAULT NULL,
  `tgl_expired` date DEFAULT NULL,
  `status` enum('aktif','suspended','nonaktif') NOT NULL DEFAULT 'aktif',
  `ip_tetap` varchar(15) DEFAULT NULL COMMENT 'Opsional static IP',
  `notes` text DEFAULT NULL,
  `created_at` datetime NOT NULL DEFAULT current_timestamp(),
  `updated_at` datetime NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  `siklus` varchar(20) DEFAULT 'postpaid',
  `periode` varchar(20) DEFAULT 'tetap',
  `ppn_persen` decimal(5,2) DEFAULT NULL COMMENT 'NULL=ikut PPN global, 0=bebas, N=override',
  `latitude` decimal(10,7) DEFAULT NULL,
  `longitude` decimal(10,7) DEFAULT NULL,
  `odc` varchar(64) DEFAULT NULL,
  `odp` varchar(64) DEFAULT NULL,
  `no_ktp` varchar(20) DEFAULT NULL,
  `tgl_lahir` date DEFAULT NULL,
  `ktp_url` varchar(255) DEFAULT NULL,
  `jarak_kabel` int(11) DEFAULT NULL,
  `foto_rumah` varchar(255) DEFAULT NULL,
  `dibuat_oleh_id` int(11) DEFAULT NULL,
  `dibuat_oleh` varchar(100) DEFAULT NULL,
  `dibuat_oleh_role` varchar(20) DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `username` (`username`),
  KEY `pelanggan_paket_id` (`paket_id`),
  KEY `pelanggan_status` (`status`),
  KEY `pelanggan_tgl_expired` (`tgl_expired`),
  KEY `pelanggan_status_expired` (`status`,`tgl_expired`),
  KEY `pelanggan_reseller_id` (`reseller_id`),
  CONSTRAINT `pelanggan_ibfk_1` FOREIGN KEY (`paket_id`) REFERENCES `paket` (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=6 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `radacct`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `radacct` (
  `radacctid` bigint(21) NOT NULL AUTO_INCREMENT,
  `acctsessionid` varchar(64) NOT NULL DEFAULT '',
  `acctuniqueid` varchar(32) NOT NULL DEFAULT '',
  `username` varchar(64) NOT NULL DEFAULT '',
  `groupname` varchar(64) NOT NULL DEFAULT '',
  `realm` varchar(64) DEFAULT '',
  `nasipaddress` varchar(15) NOT NULL DEFAULT '',
  `nasportid` varchar(64) DEFAULT NULL,
  `nasporttype` varchar(32) DEFAULT NULL,
  `acctstarttime` datetime DEFAULT NULL,
  `acctupdatetime` datetime DEFAULT NULL,
  `acctstoptime` datetime DEFAULT NULL,
  `acctinterval` int(12) DEFAULT NULL,
  `acctsessiontime` int(12) unsigned DEFAULT NULL,
  `acctauthentic` varchar(32) DEFAULT NULL,
  `connectinfo_start` varchar(50) DEFAULT NULL,
  `connectinfo_stop` varchar(50) DEFAULT NULL,
  `acctinputoctets` bigint(20) DEFAULT NULL,
  `acctoutputoctets` bigint(20) DEFAULT NULL,
  `calledstationid` varchar(50) NOT NULL DEFAULT '',
  `callingstationid` varchar(50) NOT NULL DEFAULT '',
  `acctterminatecause` varchar(32) NOT NULL DEFAULT '',
  `servicetype` varchar(32) DEFAULT NULL,
  `framedprotocol` varchar(32) DEFAULT NULL,
  `framedipaddress` varchar(15) NOT NULL DEFAULT '',
  `framedipv6address` varchar(45) DEFAULT NULL,
  `framedipv6prefix` varchar(45) DEFAULT NULL,
  `framedinterfaceid` varchar(44) DEFAULT NULL,
  `delegatedipv6prefix` varchar(45) DEFAULT NULL,
  PRIMARY KEY (`radacctid`),
  UNIQUE KEY `radacct_acctuniqueid` (`acctuniqueid`),
  KEY `radacct_username` (`username`),
  KEY `radacct_framedipaddress` (`framedipaddress`),
  KEY `radacct_acctsessionid` (`acctsessionid`),
  KEY `radacct_acctstarttime` (`acctstarttime`),
  KEY `radacct_acctstoptime` (`acctstoptime`),
  KEY `radacct_nasipaddress` (`nasipaddress`)
) ENGINE=InnoDB AUTO_INCREMENT=11 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `radcheck`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `radcheck` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `username` varchar(64) NOT NULL DEFAULT '',
  `attribute` varchar(64) NOT NULL DEFAULT '',
  `op` char(2) NOT NULL DEFAULT '==',
  `value` varchar(253) NOT NULL DEFAULT '',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uniq_user_attr` (`username`,`attribute`),
  KEY `radcheck_username` (`username`(32))
) ENGINE=InnoDB AUTO_INCREMENT=14 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `radgroupcheck`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `radgroupcheck` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `groupname` varchar(64) NOT NULL DEFAULT '',
  `attribute` varchar(64) NOT NULL DEFAULT '',
  `op` char(2) NOT NULL DEFAULT '==',
  `value` varchar(253) NOT NULL DEFAULT '',
  PRIMARY KEY (`id`),
  KEY `radgroupcheck_groupname` (`groupname`(32))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `radgroupreply`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `radgroupreply` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `groupname` varchar(64) NOT NULL DEFAULT '',
  `attribute` varchar(64) NOT NULL DEFAULT '',
  `op` char(2) NOT NULL DEFAULT '=',
  `value` varchar(253) NOT NULL DEFAULT '',
  PRIMARY KEY (`id`),
  KEY `radgroupreply_groupname` (`groupname`(32))
) ENGINE=InnoDB AUTO_INCREMENT=3 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `radpostauth`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `radpostauth` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `username` varchar(64) NOT NULL DEFAULT '',
  `pass` varchar(64) NOT NULL DEFAULT '',
  `reply` varchar(32) NOT NULL DEFAULT '',
  `authdate` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  PRIMARY KEY (`id`),
  KEY `radpostauth_username` (`username`),
  KEY `radpostauth_authdate` (`authdate`)
) ENGINE=InnoDB AUTO_INCREMENT=93 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `radreply`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `radreply` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `username` varchar(64) NOT NULL DEFAULT '',
  `attribute` varchar(64) NOT NULL DEFAULT '',
  `op` char(2) NOT NULL DEFAULT '=',
  `value` varchar(253) NOT NULL DEFAULT '',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uniq_reply_user_attr` (`username`,`attribute`),
  KEY `radreply_username` (`username`(32))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `radusergroup`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `radusergroup` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `username` varchar(64) NOT NULL DEFAULT '',
  `groupname` varchar(64) NOT NULL DEFAULT '',
  `priority` int(11) NOT NULL DEFAULT 1,
  PRIMARY KEY (`id`),
  KEY `radusergroup_username` (`username`(32))
) ENGINE=InnoDB AUTO_INCREMENT=2 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `reseller`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `reseller` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `nama` varchar(150) NOT NULL,
  `username` varchar(64) NOT NULL,
  `password` varchar(255) NOT NULL,
  `no_hp` varchar(20) NOT NULL,
  `alamat` varchar(255) DEFAULT NULL,
  `email` varchar(150) DEFAULT NULL,
  `saldo` decimal(14,2) NOT NULL DEFAULT 0.00,
  `komisi_persen` decimal(5,2) NOT NULL DEFAULT 0.00 COMMENT 'Diskon harga dari harga normal',
  `level` enum('silver','gold','platinum') NOT NULL DEFAULT 'silver',
  `status` enum('aktif','nonaktif','suspend') NOT NULL DEFAULT 'aktif',
  `token_api` varchar(64) DEFAULT NULL COMMENT 'Token untuk API reseller',
  `last_login` datetime DEFAULT NULL,
  `created_at` datetime NOT NULL DEFAULT current_timestamp(),
  `updated_at` datetime NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  PRIMARY KEY (`id`),
  UNIQUE KEY `username` (`username`),
  UNIQUE KEY `email` (`email`),
  UNIQUE KEY `token_api` (`token_api`),
  KEY `reseller_status` (`status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `reseller_harga`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `reseller_harga` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `reseller_id` int(10) unsigned NOT NULL,
  `paket_id` int(10) unsigned NOT NULL,
  `harga_reseller` decimal(12,2) NOT NULL,
  `created_at` datetime NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`),
  UNIQUE KEY `reseller_id` (`reseller_id`,`paket_id`),
  KEY `paket_id` (`paket_id`),
  CONSTRAINT `reseller_harga_ibfk_1` FOREIGN KEY (`reseller_id`) REFERENCES `reseller` (`id`),
  CONSTRAINT `reseller_harga_ibfk_2` FOREIGN KEY (`paket_id`) REFERENCES `paket` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `reseller_mutasi`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `reseller_mutasi` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `reseller_id` int(10) unsigned NOT NULL,
  `tipe` enum('topup','pembelian','refund','bonus','koreksi') NOT NULL,
  `jumlah` decimal(14,2) NOT NULL,
  `saldo_sebelum` decimal(14,2) NOT NULL,
  `saldo_sesudah` decimal(14,2) NOT NULL,
  `keterangan` varchar(255) DEFAULT NULL,
  `ref_id` varchar(100) DEFAULT NULL COMMENT 'order_id topup atau id transaksi',
  `payment_method` varchar(50) DEFAULT NULL,
  `created_at` datetime NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`),
  KEY `reseller_mutasi_reseller_id` (`reseller_id`),
  KEY `reseller_mutasi_tipe` (`tipe`),
  CONSTRAINT `reseller_mutasi_ibfk_1` FOREIGN KEY (`reseller_id`) REFERENCES `reseller` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `reseller_topup`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `reseller_topup` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `reseller_id` int(10) unsigned NOT NULL,
  `order_id` varchar(100) NOT NULL,
  `jumlah` decimal(14,2) NOT NULL,
  `payment_url` text DEFAULT NULL,
  `payment_method` varchar(50) DEFAULT NULL,
  `status` enum('pending','paid','expired','cancelled') NOT NULL DEFAULT 'pending',
  `paid_at` datetime DEFAULT NULL,
  `created_at` datetime NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`),
  UNIQUE KEY `order_id` (`order_id`),
  KEY `reseller_topup_reseller_id` (`reseller_id`),
  KEY `reseller_topup_order_id` (`order_id`),
  CONSTRAINT `reseller_topup_ibfk_1` FOREIGN KEY (`reseller_id`) REFERENCES `reseller` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `reseller_transaksi`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `reseller_transaksi` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `reseller_id` int(10) unsigned NOT NULL,
  `tipe` enum('voucher','pppoe','hotspot') NOT NULL,
  `paket_id` int(10) unsigned NOT NULL,
  `jumlah_item` int(11) NOT NULL DEFAULT 1,
  `harga_normal` decimal(12,2) NOT NULL,
  `harga_reseller` decimal(12,2) NOT NULL COMMENT 'Harga setelah diskon',
  `total_bayar` decimal(14,2) NOT NULL,
  `status` enum('success','refunded') NOT NULL DEFAULT 'success',
  `detail` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_bin DEFAULT NULL COMMENT 'Data voucher/user yang dibuat' CHECK (json_valid(`detail`)),
  `created_at` datetime NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`),
  KEY `reseller_transaksi_reseller_id` (`reseller_id`),
  KEY `reseller_transaksi_created_at` (`created_at`),
  KEY `paket_id` (`paket_id`),
  CONSTRAINT `reseller_transaksi_ibfk_1` FOREIGN KEY (`reseller_id`) REFERENCES `reseller` (`id`),
  CONSTRAINT `reseller_transaksi_ibfk_2` FOREIGN KEY (`paket_id`) REFERENCES `paket` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `router`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `router` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `nama` varchar(64) NOT NULL,
  `ip` varchar(64) NOT NULL,
  `port` int(11) NOT NULL DEFAULT 8728,
  `pakai_ssl` tinyint(1) NOT NULL DEFAULT 0,
  `api_user` varchar(64) NOT NULL,
  `api_pass` text NOT NULL,
  `aktif` tinyint(1) NOT NULL DEFAULT 1,
  `keterangan` varchar(191) DEFAULT NULL,
  `last_ok` datetime DEFAULT NULL,
  `last_error` varchar(255) DEFAULT NULL,
  `dibuat` datetime NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`),
  UNIQUE KEY `uniq_router_ip_port` (`ip`,`port`),
  KEY `idx_router_aktif` (`aktif`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `setting`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `setting` (
  `kunci` varchar(100) NOT NULL,
  `nilai` text DEFAULT NULL,
  `deskripsi` varchar(255) DEFAULT NULL,
  PRIMARY KEY (`kunci`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `stok_lokasi`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `stok_lokasi` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `nama` varchar(120) NOT NULL,
  `tipe` enum('gudang','teknisi','kendaraan') NOT NULL DEFAULT 'gudang',
  `admin_id` int(11) DEFAULT NULL,
  `keterangan` text DEFAULT NULL,
  `aktif` tinyint(1) NOT NULL DEFAULT 1,
  `dibuat` datetime NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`),
  KEY `idx_lokasi_admin` (`admin_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `stok_mutasi`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `stok_mutasi` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `tanggal` date NOT NULL,
  `jenis` enum('masuk','keluar') NOT NULL,
  `sebab` enum('pembelian','pemakaian','transfer','opname','retur') NOT NULL DEFAULT 'pemakaian',
  `barang_id` int(11) NOT NULL,
  `lokasi_id` int(11) NOT NULL,
  `pair_id` int(11) DEFAULT NULL,
  `qty` int(11) NOT NULL,
  `harga_satuan` decimal(14,2) NOT NULL DEFAULT 0.00,
  `tujuan_tipe` enum('pelanggan','tiket','lokasi','rusak','hilang','lain') DEFAULT NULL,
  `pelanggan_id` int(11) DEFAULT NULL,
  `tiket_id` int(11) DEFAULT NULL,
  `pengeluaran_id` int(11) DEFAULT NULL,
  `no_ref` varchar(80) DEFAULT NULL,
  `keterangan` text DEFAULT NULL,
  `dibuat_oleh` varchar(80) DEFAULT NULL,
  `dibuat_pada` datetime NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`),
  KEY `idx_mut_barang_lokasi` (`barang_id`,`lokasi_id`),
  KEY `idx_mut_tanggal` (`tanggal`),
  KEY `idx_mut_pair` (`pair_id`),
  KEY `idx_mut_pelanggan` (`pelanggan_id`),
  KEY `idx_mut_tiket` (`tiket_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `stok_unit`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `stok_unit` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `barang_id` int(11) NOT NULL,
  `serial_number` varchar(80) NOT NULL,
  `mac` varchar(40) DEFAULT NULL,
  `status` enum('tersedia','terpasang','rusak','hilang') NOT NULL DEFAULT 'tersedia',
  `lokasi_id` int(11) DEFAULT NULL,
  `pelanggan_id` int(11) DEFAULT NULL,
  `tiket_id` int(11) DEFAULT NULL,
  `mutasi_masuk_id` int(11) DEFAULT NULL,
  `mutasi_keluar_id` int(11) DEFAULT NULL,
  `catatan` text DEFAULT NULL,
  `sejak` datetime DEFAULT NULL,
  `dibuat` datetime NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_unit_sn` (`barang_id`,`serial_number`),
  KEY `idx_unit_status` (`status`),
  KEY `idx_unit_lokasi` (`lokasi_id`),
  KEY `idx_unit_masuk` (`mutasi_masuk_id`),
  KEY `idx_unit_keluar` (`mutasi_keluar_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `tiket`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `tiket` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `pelanggan_id` int(10) unsigned NOT NULL,
  `judul` varchar(200) NOT NULL,
  `pesan` text NOT NULL,
  `kategori` enum('umum','gangguan','billing','lainnya','psb') DEFAULT 'umum',
  `prioritas` enum('rendah','sedang','tinggi','urgent') DEFAULT 'sedang',
  `perkiraan_perbaikan` datetime DEFAULT NULL,
  `teknisi_ids` varchar(255) DEFAULT NULL,
  `foto` varchar(255) DEFAULT NULL,
  `status` enum('open','proses','selesai') DEFAULT 'open',
  `created_at` timestamp NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  `is_psb` tinyint(4) DEFAULT 0,
  `psb_nama` varchar(120) DEFAULT NULL,
  `psb_hp` varchar(30) DEFAULT NULL,
  `psb_alamat` varchar(255) DEFAULT NULL,
  `psb_lat` decimal(10,7) DEFAULT NULL,
  `psb_lng` decimal(10,7) DEFAULT NULL,
  `diproses_oleh` varchar(120) DEFAULT NULL,
  `diproses_oleh_id` int(10) unsigned DEFAULT NULL,
  `diproses_at` datetime DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `tiket_pelanggan` (`pelanggan_id`),
  CONSTRAINT `tiket_ibfk_1` FOREIGN KEY (`pelanggan_id`) REFERENCES `pelanggan` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `tiket_reply`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `tiket_reply` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `tiket_id` int(10) unsigned NOT NULL,
  `dari` enum('pelanggan','admin') DEFAULT 'admin',
  `pesan` text NOT NULL,
  `foto` varchar(255) DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`),
  KEY `reply_tiket` (`tiket_id`),
  CONSTRAINT `tiket_reply_ibfk_1` FOREIGN KEY (`tiket_id`) REFERENCES `tiket` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `v_pelanggan_aktif`;
/*!50001 DROP VIEW IF EXISTS `v_pelanggan_aktif`*/;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8mb4;
/*!50001 CREATE VIEW `v_pelanggan_aktif` AS SELECT
 1 AS `id`,
  1 AS `nama`,
  1 AS `username`,
  1 AS `no_hp`,
  1 AS `tipe_koneksi`,
  1 AS `tgl_expired`,
  1 AS `status`,
  1 AS `nama_paket`,
  1 AS `kecepatan_dn`,
  1 AS `harga`,
  1 AS `sisa_hari` */;
SET character_set_client = @saved_cs_client;
DROP TABLE IF EXISTS `v_sesi_aktif`;
/*!50001 DROP VIEW IF EXISTS `v_sesi_aktif`*/;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8mb4;
/*!50001 CREATE VIEW `v_sesi_aktif` AS SELECT
 1 AS `username`,
  1 AS `ip`,
  1 AS `nas_ip`,
  1 AS `mulai`,
  1 AS `durasi_menit`,
  1 AS `total_mb`,
  1 AS `nas_name` */;
SET character_set_client = @saved_cs_client;
DROP TABLE IF EXISTS `v_tagihan_jatuh_tempo`;
/*!50001 DROP VIEW IF EXISTS `v_tagihan_jatuh_tempo`*/;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8mb4;
/*!50001 CREATE VIEW `v_tagihan_jatuh_tempo` AS SELECT
 1 AS `id`,
  1 AS `no_invoice`,
  1 AS `jumlah`,
  1 AS `tgl_jatuh_tempo`,
  1 AS `status`,
  1 AS `nama_pelanggan`,
  1 AS `no_hp`,
  1 AS `username`,
  1 AS `sisa_hari` */;
SET character_set_client = @saved_cs_client;
DROP TABLE IF EXISTS `voucher`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `voucher` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `username` varchar(32) NOT NULL,
  `password` varchar(32) NOT NULL,
  `paket_id` int(10) unsigned NOT NULL,
  `batch_id` varchar(30) DEFAULT NULL,
  `status` enum('unused','used','expired') NOT NULL DEFAULT 'unused',
  `digunakan_oleh` varchar(64) DEFAULT NULL COMMENT 'no WA/MAC yang pakai',
  `tgl_digunakan` datetime DEFAULT NULL,
  `tgl_expired` datetime DEFAULT NULL,
  `created_at` datetime NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`),
  UNIQUE KEY `username` (`username`),
  KEY `voucher_status` (`status`),
  KEY `voucher_paket_id` (`paket_id`),
  CONSTRAINT `voucher_ibfk_1` FOREIGN KEY (`paket_id`) REFERENCES `paket` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `voucher_template`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `voucher_template` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `nama` varchar(100) NOT NULL,
  `header_html` text DEFAULT NULL,
  `row_html` text NOT NULL,
  `footer_html` text DEFAULT NULL,
  `is_default` tinyint(1) DEFAULT 0,
  `created_at` timestamp NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=2 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `vpn_account`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `vpn_account` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `nama` varchar(100) NOT NULL COMMENT 'Label/nama akun VPN',
  `protokol` enum('wireguard','l2tp') NOT NULL DEFAULT 'wireguard',
  `server` varchar(255) NOT NULL COMMENT 'Endpoint/IP server VPN',
  `port` int(11) NOT NULL DEFAULT 51820,
  `username` varchar(100) NOT NULL,
  `password` text DEFAULT NULL COMMENT 'Password / PSK (terenkripsi AES-256-GCM)',
  `pubkey` text DEFAULT NULL COMMENT 'Public key WireGuard peer',
  `allowed_ips` varchar(255) DEFAULT '0.0.0.0/0' COMMENT 'WireGuard allowed IPs',
  `ip_tunnel` varchar(64) DEFAULT NULL COMMENT 'IP tunnel peer WireGuard (mis 10.10.28.4/32)',
  `ipsec_psk` text DEFAULT NULL COMMENT 'IPSec Pre-Shared Key untuk L2TP',
  `nas_id` int(11) DEFAULT NULL COMMENT 'NAS terkait (opsional)',
  `status` enum('aktif','nonaktif') NOT NULL DEFAULT 'aktif',
  `catatan` text DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`),
  KEY `vpn_nas` (`nas_id`)
) ENGINE=InnoDB AUTO_INCREMENT=2 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci COMMENT='Akun VPN untuk koneksi NAS/Mikrotik';
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `wa_log`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `wa_log` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `pelanggan_id` int(10) unsigned DEFAULT NULL,
  `no_tujuan` varchar(64) DEFAULT NULL,
  `pesan` text NOT NULL,
  `tipe` enum('reminder','suspend','konfirmasi_bayar','otp','manual','broadcast','daftar','voucher','invoice_pdf','dokumen','tiket','absensi') NOT NULL,
  `status` enum('pending','sent','failed') NOT NULL DEFAULT 'pending',
  `response` text DEFAULT NULL COMMENT 'Response dari API WA',
  `invoice_id` int(10) unsigned DEFAULT NULL,
  `sent_at` datetime DEFAULT NULL,
  `created_at` datetime NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`),
  KEY `wa_log_pelanggan_id` (`pelanggan_id`),
  KEY `wa_log_status` (`status`),
  KEY `wa_log_tipe` (`tipe`)
) ENGINE=InnoDB AUTO_INCREMENT=4 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!50001 DROP VIEW IF EXISTS `v_pelanggan_aktif`*/;
/*!50001 SET @saved_cs_client          = @@character_set_client */;
/*!50001 SET @saved_cs_results         = @@character_set_results */;
/*!50001 SET @saved_col_connection     = @@collation_connection */;
/*!50001 SET character_set_client      = utf8mb3 */;
/*!50001 SET character_set_results     = utf8mb3 */;
/*!50001 SET collation_connection      = utf8mb3_general_ci */;
/*!50001 CREATE ALGORITHM=UNDEFINED */
/*!50013 SQL SECURITY DEFINER */
/*!50001 VIEW `v_pelanggan_aktif` AS select `p`.`id` AS `id`,`p`.`nama` AS `nama`,`p`.`username` AS `username`,`p`.`no_hp` AS `no_hp`,`p`.`tipe_koneksi` AS `tipe_koneksi`,`p`.`tgl_expired` AS `tgl_expired`,`p`.`status` AS `status`,`pk`.`nama` AS `nama_paket`,`pk`.`kecepatan_dn` AS `kecepatan_dn`,`pk`.`harga` AS `harga`,to_days(`p`.`tgl_expired`) - to_days(curdate()) AS `sisa_hari` from (`pelanggan` `p` join `paket` `pk` on(`p`.`paket_id` = `pk`.`id`)) where `p`.`status` <> 'nonaktif' */;
/*!50001 SET character_set_client      = @saved_cs_client */;
/*!50001 SET character_set_results     = @saved_cs_results */;
/*!50001 SET collation_connection      = @saved_col_connection */;
/*!50001 DROP VIEW IF EXISTS `v_sesi_aktif`*/;
/*!50001 SET @saved_cs_client          = @@character_set_client */;
/*!50001 SET @saved_cs_results         = @@character_set_results */;
/*!50001 SET @saved_col_connection     = @@collation_connection */;
/*!50001 SET character_set_client      = utf8mb3 */;
/*!50001 SET character_set_results     = utf8mb3 */;
/*!50001 SET collation_connection      = utf8mb3_general_ci */;
/*!50001 CREATE ALGORITHM=UNDEFINED */
/*!50013 SQL SECURITY DEFINER */
/*!50001 VIEW `v_sesi_aktif` AS select `ra`.`username` AS `username`,`ra`.`framedipaddress` AS `ip`,`ra`.`nasipaddress` AS `nas_ip`,`ra`.`acctstarttime` AS `mulai`,timestampdiff(MINUTE,`ra`.`acctstarttime`,current_timestamp()) AS `durasi_menit`,round((`ra`.`acctinputoctets` + `ra`.`acctoutputoctets`) / 1048576,2) AS `total_mb`,`n`.`shortname` AS `nas_name` from (`radacct` `ra` left join `nas` `n` on(`ra`.`nasipaddress` = `n`.`nasname`)) where `ra`.`acctstoptime` is null */;
/*!50001 SET character_set_client      = @saved_cs_client */;
/*!50001 SET character_set_results     = @saved_cs_results */;
/*!50001 SET collation_connection      = @saved_col_connection */;
/*!50001 DROP VIEW IF EXISTS `v_tagihan_jatuh_tempo`*/;
/*!50001 SET @saved_cs_client          = @@character_set_client */;
/*!50001 SET @saved_cs_results         = @@character_set_results */;
/*!50001 SET @saved_col_connection     = @@collation_connection */;
/*!50001 SET character_set_client      = utf8mb3 */;
/*!50001 SET character_set_results     = utf8mb3 */;
/*!50001 SET collation_connection      = utf8mb3_general_ci */;
/*!50001 CREATE ALGORITHM=UNDEFINED */
/*!50013 SQL SECURITY DEFINER */
/*!50001 VIEW `v_tagihan_jatuh_tempo` AS select `i`.`id` AS `id`,`i`.`no_invoice` AS `no_invoice`,`i`.`jumlah` AS `jumlah`,`i`.`tgl_jatuh_tempo` AS `tgl_jatuh_tempo`,`i`.`status` AS `status`,`p`.`nama` AS `nama_pelanggan`,`p`.`no_hp` AS `no_hp`,`p`.`username` AS `username`,to_days(`i`.`tgl_jatuh_tempo`) - to_days(curdate()) AS `sisa_hari` from (`invoice` `i` join `pelanggan` `p` on(`i`.`pelanggan_id` = `p`.`id`)) where `i`.`status` in ('unpaid','overdue') order by `i`.`tgl_jatuh_tempo` */;
/*!50001 SET character_set_client      = @saved_cs_client */;
/*!50001 SET character_set_results     = @saved_cs_results */;
/*!50001 SET collation_connection      = @saved_col_connection */;
/*!40103 SET TIME_ZONE=@OLD_TIME_ZONE */;

/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;

