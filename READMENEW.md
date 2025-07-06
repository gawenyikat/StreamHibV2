# StreamHibV2

> **Tanggal Rilis**: 06/07/2025 (Diperbarui)
> **Status**: Bismillah, dalam tahap pengembangan (StreamHibV2)
> **Fungsi**: Platform manajemen streaming berbasis Flask + FFmpeg, cocok untuk server Regxa, Contabo, Hetzner, dan Biznet. Mendukung **banyak pengguna dalam satu server** dengan instans dan domain terpisah.

---

## ✨ Fitur Utama

* Panel kontrol streaming berbasis web (Flask)

* Dilengkapi dengan WebSocket dan FFmpeg

* **Dukungan Multi-Instans**: Jalankan beberapa salinan aplikasi di satu server untuk pengguna berbeda.

* **Instalasi Mudah per Instans**: Skrip installer yang disederhanakan untuk setiap instans pengguna.

* Autostart service via `systemd`

* Transfer dan backup video dari server lama

* **🔄 Sistem Migrasi Seamless**: Recovery otomatis sesi dan jadwal per instans.

* **🚀 Migration Wizard**: Transfer data dari server lama dengan 1 klik.

* **🌐 Sistem Domain Terintegrasi**: Support domain kustom unik per instans dengan SSL.

* **Manajemen Kuota Disk (via OS)**: Batasi penggunaan penyimpanan per instans pengguna.

---

## 🧱 Prasyarat

* Server berbasis Debian (Regxa, Contabo, Hetzner, Biznet)

* Akses root atau user dengan sudo

* SSH key aktif (khusus Biznet)

* Port yang akan digunakan untuk setiap instans harus terbuka untuk publik (misal 5000, 5001, 5002, dst.)

* Domain (opsional, untuk akses yang lebih profesional dan unik per pengguna)

---

### 🚀 Instalasi Instans Pengguna (Disarankan)

Gunakan skrip `install_user_instance.sh` untuk menginstal setiap instans StreamHibV2. Ini adalah metode yang direkomendasikan untuk satu pengguna atau banyak pengguna di satu server.

#### 1. Persiapan Awal (Jalankan Sekali per Server)

Pastikan dependensi dasar sistem terinstal. Anda hanya perlu menjalankan ini satu kali di server baru Anda.

```bash
sudo apt update && sudo apt upgrade -y && sudo apt dist-upgrade -y
sudo apt install -y python3 python3-pip python3-venv ffmpeg git curl wget sudo ufw nginx certbot python3-certbot-nginx gunicorn eventlet
sudo pip3 install gdown paramiko scp
```

#### 2. Unduh Skrip Installer Instans

Unduh skrip `install_user_instance.sh` ke server Anda.

```bash
wget https://raw.githubusercontent.com/gawenyikat/StreamHibV2/main/install_user_instance.sh
chmod +x install_user_instance.sh
```

#### 3. Jalankan Installer untuk Setiap Instans Pengguna

Untuk setiap pengguna atau instans yang ingin Anda buat, jalankan skrip dengan memberikan **nama unik** untuk instans tersebut (bisa nama pengguna) dan **port unik** yang akan digunakannya.

**Contoh:**

* **Untuk pengguna "budi" di port 5001:**

  ```bash
  sudo bash install_user_instance.sh budi 5001
  ```

* **Untuk pengguna "ayu" di port 5002:**

  ```bash
  sudo bash install_user_instance.sh ayu 5002
  ```

* **Untuk instans utama/default di port 5000 (jika hanya 1 user atau sebagai instans utama):**

  ```bash
  sudo bash install_user_instance.sh utama 5000
  ```

Setiap perintah di atas akan:

* Mengunduh kode StreamHibV2 ke direktori unik (`/root/StreamHibV2-budi`, `/root/StreamHibV2-ayu`, dll.).

* Membuat lingkungan virtual dan menginstal dependensi Python di dalamnya.

* Membuka port yang ditentukan di firewall (`ufw`).

* Membuat layanan `systemd` yang unik (`streamhibv2-budi.service`, `streamhibv2-ayu.service`, dll.) untuk instans tersebut.

* Mengonfigurasi aplikasi untuk menggunakan file data (sessions.json, users.json, videos) yang terpisah di direktori instansnya sendiri.

* Memulai layanan.

---

## 🌐 Setup Domain per Instans (Opsional)

StreamHibV2 mendukung konfigurasi domain kustom dengan SSL otomatis menggunakan Let's Encrypt **untuk setiap instans terpisah**.

### Cara Setup Domain:

#### 1. Persiapan Domain

* Pastikan setiap subdomain unik Anda (misalnya `budi.domainanda.com`, `ayu.domainanda.com`) sudah mengarah ke **IP publik server Anda**.

* Buat catatan A record untuk setiap subdomain:

  * `budi.domainanda.com` → `IP_SERVER_ANDA`

  * `ayu.domainanda.com` → `IP_SERVER_ANDA`

* Tunggu propagasi DNS (biasanya 5-15 menit).

#### 2. Setup melalui Web Interface (per Instans)

1. Akses panel StreamHib untuk instans spesifik (misalnya, untuk "budi": `http://IP_SERVER_ANDA:5001`).

2. Login ke panel admin (default: `admin` / `streamhib2025`).

3. Masuk ke menu **Pengaturan Domain**.

4. Masukkan nama domain unik untuk instans tersebut (contoh: `budi.domainanda.com`).

5. Pilih apakah ingin mengaktifkan SSL.

6. Klik **Setup Domain**.

Nginx di server Anda akan secara otomatis dikonfigurasi untuk merutekan permintaan dari `budi.domainanda.com` ke port `5001` (instans "budi"), dan seterusnya untuk setiap domain dan port instans lainnya.

### Keunggulan Menggunakan Domain:

* ✅ **Akses Profesional**: `https://budi.domainanda.com` vs `http://123.456.789.0:5001`

* ✅ **SSL Otomatis**: Sertifikat Let's Encrypt gratis per domain.

* ✅ **Migrasi Seamless**: Saat migrasi server, Anda hanya perlu mengubah A record domain, pelanggan tidak perlu tahu perubahan IP!

* ✅ **Branding**: Menggunakan domain sendiri untuk setiap pelanggan.

---

## 🗄️ Manajemen Kuota Disk per Instans (Opsional)

Dengan setiap instans StreamHibV2 memiliki direktori `videos` sendiri (`/root/StreamHibV2-<username_instans>/videos`), Anda dapat menerapkan kuota disk di tingkat sistem operasi Linux.

**Langkah-langkah Umum (Membutuhkan akses root dan harus diikuti dengan hati-hati):**

1. **Instal alat kuota:**

   ```bash
   sudo apt install quota -y
   ```

2. **Backup file `/etc/fstab` (SANGAT PENTING!):**
   Ini adalah langkah krusial. Jika terjadi kesalahan, Anda bisa mengembalikan file asli.

   ```bash
   sudo cp /etc/fstab /etc/fstab.bak
   ```

3. **Edit `/etc/fstab` untuk mengaktifkan kuota:**
   Buka file konfigurasi `fstab` dengan editor `nano`.

   ```bash
   sudo nano /etc/fstab
   ```

   Cari baris yang sesuai dengan partisi root Anda (biasanya `/`). Ini akan terlihat mirip dengan:
   `UUID=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx / ext4 defaults 0 1`
   Atau mungkin:
   `/dev/sda1 / ext4 defaults 0 1`

   Tambahkan opsi `,usrjquota=aquota.user,grpjquota=aquota.group,jqfmt=vfsv0` ke opsi mount yang sudah ada (setelah `defaults`). Pastikan untuk memisahkannya dengan koma.

   **Contoh setelah perubahan:**
   `UUID=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx / ext4 defaults,usrjquota=aquota.user,grpjquota=aquota.group,jqfmt=vfsv0 0 1`
   *(Jangan ubah `UUID` atau `/dev/sda1` yang sudah ada di sistem Anda. Hanya tambahkan opsi kuota setelah `defaults`.)*

   **Simpan dan keluar dari editor:**

   * Tekan `Ctrl+O` (untuk menyimpan), lalu `Enter`.

   * Tekan `Ctrl+X` (untuk keluar).

4. **Pasang ulang partisi untuk menerapkan perubahan `fstab`:**
   Ini adalah langkah penting untuk menguji perubahan `fstab` tanpa perlu me-reboot. Jika ada kesalahan di `fstab`, perintah ini akan gagal.

   ```bash
   sudo mount -o remount /
   ```

   Jika perintah ini berhasil tanpa error, lanjutkan ke langkah berikutnya. Jika ada error, segera perbaiki file `/etc/fstab` atau kembalikan dari backup (`sudo cp /etc/fstab.bak /etc/fstab`).

5. **Buat file kuota dan aktifkan kuota:**

   ```bash
   sudo quotacheck -cum /
   sudo quotaon -ug /
   ```

6. **Buat pengguna sistem unik untuk setiap instans (Disarankan):**
   Secara default, instans berjalan sebagai `root`. Untuk kuota yang lebih granular, buat pengguna sistem non-root terpisah untuk setiap instans. Lakukan ini **untuk setiap instans** yang ingin Anda batasi kuotanya.

   * **Buat pengguna sistem baru:**

     ```bash
     sudo adduser --system --no-create-home streamhib_budi # Ganti 'streamhib_budi' dengan nama user unik
     ```

   * **Ubah kepemilikan direktori instans:**

     ```bash
     sudo chown -R streamhib_budi:streamhib_budi /root/StreamHibV2-budi # Ganti dengan direktori instans yang sesuai
     ```

   * **Edit file layanan `systemd` instans:**
     Buka file layanan `systemd` untuk instans tersebut.

     ```bash
     sudo nano /etc/systemd/system/streamhibv2-budi.service # Ganti dengan nama layanan instans yang sesuai
     ```

     Cari baris `User=root` dan ubah menjadi `User=streamhib_budi` (ganti dengan nama user sistem yang baru Anda buat).

     **Contoh perubahan di file service:**

     ```ini
     [Service]
     # ... baris lainnya ...
     User=streamhib_budi # Ganti 'root' dengan user sistem baru
     # ... baris lainnya ...
     ```

     **Simpan dan keluar dari editor.**

   * **Reload daemon systemd dan restart layanan instans:**

     ```bash
     sudo systemctl daemon-reload
     sudo systemctl restart streamhibv2-budi.service # Ganti dengan nama layanan instans yang sesuai
     ```

7. **Tetapkan kuota untuk pengguna sistem:**
   Gunakan `edquota` untuk menetapkan batas kuota untuk pengguna sistem yang baru Anda buat.

   ```bash
   sudo edquota -u streamhib_budi # Ganti 'streamhib_budi' dengan nama user sistem yang sesuai
   ```

   Ini akan membuka editor teks (biasanya `vi` atau `nano`). Anda akan melihat baris untuk pengguna `streamhib_budi` dan kolom untuk kuota.

   **Contoh baris yang perlu diubah (nilai dalam KB):**
   `streamhib_budi /dev/sda1 0 0 0 0` (ini yang akan Anda lihat awalnya)

   Ubah nilai `blocks` (penyimpanan) dan `inodes` (jumlah file).

   * Kolom ke-3: `soft limit` untuk `blocks` (dalam KB).

   * Kolom ke-4: `hard limit` untuk `blocks` (dalam KB).

   * Kolom ke-5: `soft limit` untuk `inodes` (jumlah file).

   * Kolom ke-6: `hard limit` untuk `inodes` (jumlah file).

   **Misalnya, untuk 30GB soft limit dan 35GB hard limit:**
   ($1 \text{ GB} = 1024 \times 1024 \text{ KB} = 1048576 \text{ KB}$)
   $30 \text{ GB} = 30 \times 1048576 \text{ KB} = 31457280 \text{ KB}$
   $35 \text{ GB} = 35 \times 1048576 \text{ KB} = 36700160 \text{ KB}$

   Maka barisnya akan menjadi:
   `streamhib_budi /dev/sda1 31457280 36700160 0 0`
   *(Anda bisa membiarkan `inodes` 0 0 jika tidak ingin membatasi jumlah file, atau berikan nilai yang besar seperti 1000000 1100000)*

   **Simpan dan keluar dari editor.**

8. **Verifikasi kuota:**

   ```bash
   sudo repquota -a # Melihat ringkasan kuota untuk semua filesystem
   sudo quota -s -u streamhib_budi # Melihat kuota untuk user spesifik (ganti nama user)
   ```

---

## 🔄 Migrasi Server Seamless

StreamHibV2 dilengkapi dengan **Migration Wizard** dan sistem recovery otomatis yang memungkinkan migrasi server tanpa downtime yang signifikan **untuk setiap instans secara terpisah**.

### Cara Kerja Migrasi:

1. **Server A** (lama) tetap berjalan selama proses migrasi.

2. **Server B** (baru) disetup dengan instans StreamHibV2 yang sama.

3. **Migration Wizard** otomatis transfer data via SSH.

4. Sistem recovery otomatis mendeteksi dan memulihkan:

   * Sesi streaming yang terputus

   * Jadwal yang hilang

   * Service systemd yang tidak aktif

### Langkah Migrasi (Otomatis dengan Migration Wizard):

#### 1. Setup Server Baru (Server B)

Instal instans StreamHibV2 di server baru menggunakan skrip `install_user_instance.sh` untuk setiap pengguna yang ingin Anda migrasikan. Pastikan nama instans dan portnya sama dengan di server lama.

#### 2. Gunakan Migration Wizard (per Instans)

1. Login ke Admin Panel instans yang ingin dimigrasikan di server baru (misal `http://IP_SERVER_BARU:5001/admin` untuk instans "budi").

2. Masuk menu **Migration**.

3. Input detail server lama:

   * IP Address server lama

   * Username (biasanya `root`)

   * Password server lama

4. Klik **Test Connection** untuk validasi.

5. Klik **Start Migration** untuk mulai transfer data instans tersebut.

6. Tunggu proses selesai (real-time progress).

7. Klik **Start Recovery** untuk me-restore sesi dan jadwal instans tersebut.

#### 3. Files yang Ditransfer Otomatis (per Instans)

* ✅ `sessions.json` - Data sesi dan jadwal instans ini.

* ✅ `users.json` - Data pengguna instans ini.

* ✅ `domain_config.json` - Konfigurasi domain instans ini.

* ✅ Semua video files (mp4, avi, mkv, mov) dari direktori `videos` instans ini.

#### 4. Update DNS (jika menggunakan domain)

Setelah migrasi selesai dan Anda memastikan instans berjalan normal di server baru, perbarui catatan A DNS untuk setiap domain instans agar menunjuk ke IP server baru.

```bash
# Contoh update A record domain ke IP server baru (gunakan alat penyedia DNS Anda)
# Misal untuk budi.domainanda.com:
# Tipe: A, Nama: budi, Nilai: NEW_SERVER_IP
```

#### 5. Matikan Server Lama

Setelah memastikan semua berjalan normal di server baru, matikan server lama.

---

## 🔍 Perintah Tambahan (per Instans)

Untuk mengelola instans spesifik, gunakan nama layanan `systemd` yang unik (`streamhibv2-<username_instans>.service`).

* **Cek status instans:**
  `sudo systemctl status streamhibv2-<username_instans>.service`
  (Contoh: `sudo systemctl status streamhibv2-budi.service`)

* **Stop Service instans:**
  `sudo systemctl stop streamhibv2-<username_instans>.service`

* **Restart Service instans:**
  `sudo systemctl restart streamhibv2-<username_instans>.service`

* **Cek Log Langsung instans:**
  `journalctl -u streamhibv2-<username_instans>.service -f`

* **Cek Log Recovery instans:**
  `journalctl -u streamhibv2-<username_instans>.service -f | grep RECOVERY`

* **Cek Log Domain instans:**
  `journalctl -u streamhibv2-<username_instans>.service -f | grep DOMAIN`

* **Tes Manual (Tanpa systemd) instans:**
  Masuk ke direktori instans dan jalankan:

  ```bash
  cd /root/StreamHibV2-<username_instans>
  source venv/bin/activate
  python -m flask run --host=0.0.0.0 --port=<port_instans>
  ```

---

## 🛠 Troubleshooting

### 1. Hetzner Read-Only System

Jika terkena update dan sistem menjadi **Read-Only**:

1. Masuk **Rescue Mode** dan catat password.

2. Jalankan:

   ```bash
   fsck -y /dev/sda1
   reboot
   ```

---

### 2. Error `gdown` karena cookies

Jika error setelah disk penuh:

1. Cek kapasitas:

   ```bash
   df -h
   ```

2. Hapus cache gdown:

   ```bash
   rm -rf /root/.cache/gdown/
   ```

---

### 3. Recovery Tidak Berjalan

Jika sistem recovery tidak berjalan otomatis:

1. Cek status scheduler untuk instans spesifik:

   ```bash
   journalctl -u streamhibv2-<username_instans>.service -f | grep "Scheduler dimulai"
   ```

2. Restart service instans:

   ```bash
   sudo systemctl restart streamhibv2-<username_instans>.service
   ```

3. Trigger recovery manual melalui API (akses API instans spesifik):

   ```bash
   curl -X POST http://localhost:<port_instans>/api/recovery/manual \
        -H "Content-Type: application/json" \
        --cookie "session=your_session_cookie_instans_ini"
   ```

---

### 4. Sesi Tidak Terpulihkan

Jika ada sesi yang tidak terpulihkan setelah migrasi:

1. Cek file video ada di direktori instans:

   ```bash
   ls -la /root/StreamHibV2-<username_instans>/videos/
   ```

2. Cek data `sessions.json` instans:

   ```bash
   cat /root/StreamHibV2-<username_instans>/sessions.json | jq '.active_sessions'
   ```

3. Cek service systemd instans:

   ```bash
   systemctl list-units --type=service | grep stream-
   ```

4. Trigger recovery manual dari web interface atau API instans tersebut.

---

### 5. Masalah Domain

Jika domain tidak bisa diakses:

1. Cek DNS propagation:

   ```bash
   nslookup yourdomain.com
   dig yourdomain.com
   ```

2. Cek konfigurasi Nginx:

   ```bash
   nginx -t
   systemctl status nginx
   ```

3. Cek SSL certificate:

   ```bash
   certbot certificates
   ```

4. Cek log Nginx:

   ```bash
   tail -f /var/log/nginx/error.log
   ```

---

### 6. Migrasi Video Lama

Salin folder video dari server lama ke direktori instans yang sesuai di server baru:

```bash
# Contoh untuk instans 'budi':
scp -r root@server_lama:/root/StreamHibV2-budi/videos /root/StreamHibV2-budi/
```

---

## ✅ Selesai!

Akses aplikasi melalui browser:

**Dengan IP & Port (untuk setiap instans):**

```
http://<IP-Server>:<Port-Instans>
```

Contoh: `http://192.168.1.100:5001`

**Dengan Domain (setelah konfigurasi di panel admin instans):**

```
https://<domain-unik-anda>
```

Contoh: `https://budi.domainanda.com`

StreamHibV2 siap digunakan untuk kebutuhan live streaming Anda dengan sistem multi-instans yang fleksibel, migrasi seamless, dan domain terintegrasi!

### 🎯 Keunggulan Multi-Instans, Migrasi Seamless & Domain:

* ✅ **Multi-Pengguna di Satu Server**: Setiap pengguna mendapatkan lingkungan StreamHibV2 yang terpisah.

* ✅ **Data Terisolasi**: File sesi, pengguna, dan video terpisah per instans.

* ✅ **Zero Downtime Migrasi per Instans**: Live stream tetap berjalan selama migrasi instans.

* ✅ **1-Click Migration per Instans**: Transfer semua data instans dengan Migration Wizard.

* ✅ **Real-time Progress**: Monitor progres transfer secara live.

* ✅ **Auto Recovery**: Sistem otomatis memulihkan sesi yang terputus.

* ✅ **Data Integrity**: Validasi data sebelum recovery.

* ✅ **Real-time Monitoring**: Log detail per instans untuk tracking proses.

* ✅ **Manual Trigger**: Bisa dipicu manual jika diperlukan.

* ✅ **Domain Support Unik**: Akses profesional dengan SSL gratis per domain unik.

* ✅ **Customer Friendly**: Pelanggan tidak perlu tahu perubahan teknis atau port.

* ✅ **Error Handling**: Retry dan rollback otomatis jika gagal.

* ✅ **Kuota Disk**: Kontrol penggunaan penyimpanan per instans.
