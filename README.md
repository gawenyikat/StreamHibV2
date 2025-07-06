# StreamHibV2 - Panduan Lengkap Multi-Instans

> **Tanggal Rilis**: 06/07/2025 (Diperbarui)
> **Fungsi**: Platform manajemen streaming berbasis Flask + FFmpeg. Panduan ini menjelaskan cara mengonfigurasi **satu server untuk banyak pengguna**, dengan setiap pengguna memiliki instans StreamHibV2 yang terpisah, port unik, domain kustom, dan kuota penyimpanan yang ditentukan.

## ✨ Fitur Utama yang Didukung Panduan Ini

* **Dukungan Multi-Instans**: Jalankan beberapa salinan aplikasi di satu server untuk pengguna berbeda.

* **Instalasi Otomatis per Instans**: Skrip installer yang mengotomatiskan sebagian besar proses.

* **Manajemen Pengguna Sistem Otomatis**: Membuat user Linux unik per instans.

* **Manajemen Kuota Disk (via OS)**: Batasi penggunaan penyimpanan per instans pengguna, tercermin di UI.

* **Sistem Domain Terintegrasi**: Dukungan domain kustom unik per instans dengan SSL.

* **Autostart Service**: Layanan berjalan otomatis via `systemd`.

* **Migrasi Seamless**: Fitur transfer dan backup data instans.

## 🧱 Prasyarat

* Server berbasis Debian (Debian 11+, Ubuntu 20.04+).

* Akses `root` atau user dengan `sudo`.

* SSH key aktif (khusus Biznet, jika relevan untuk Anda).

* Port yang akan digunakan untuk setiap instans harus terbuka untuk publik (misal 5001, 5002, dst.).

* Domain (opsional, untuk akses yang lebih profesional dan unik per pengguna).

## 🚀 Panduan Langkah demi Langkah

Panduan ini akan memandu Anda melalui persiapan server, modifikasi kode, instalasi setiap instans, dan konfigurasi pasca-instalasi.

### **Bagian A: Persiapan Awal Server (Lakukan CUKUP SEKALI per SERVER FISIK)**

Langkah-langkah ini menyiapkan fondasi sistem operasi Anda.

1.  **Login ke Server Anda** sebagai `root` (atau `sudo su -`).

2.  **Perbarui Sistem dan Instal Dependensi Global:**
    Ini akan menginstal semua alat sistem yang dibutuhkan oleh StreamHibV2 dan `quota`.

    ```bash
    sudo apt update && sudo apt upgrade -y && sudo apt dist-upgrade -y
    sudo apt install -y python3 python3-pip python3-venv ffmpeg git curl wget sudo ufw nginx certbot python3-certbot-nginx quota
    sudo pip3 install gdown paramiko scp
    ```

3.  **Modifikasi `/etc/fstab` untuk Mengaktifkan Kuota Disk:**
    Ini adalah langkah krusial agar sistem operasi dapat melacak dan membatasi penggunaan disk per pengguna.

    * **Backup `fstab` (SANGAT PENTING!):**

        ```bash
        sudo cp /etc/fstab /etc/fstab.bak
        
        ```

    * **Buka `fstab` dengan editor `nano`:**

        ```bash
        sudo nano /etc/fstab
        
        ```

    * **Cari** baris **partisi root Anda (`/`).** Contohnya mungkin terlihat seperti ini:
        `UUID=00944838-9498-46f2-bd9e-e84e0eedd91a / ext4 errors=remount-ro 0 1`
        Atau:
        `/dev/sda1 / ext4 defaults 0 1`

    * **Tambahkan opsi kuota:** Tambahkan `,usrquota,grpquota` ke opsi yang sudah ada.

        **Contoh** setelah perubahan **(sesuaikan dengan baris Anda):**

        ```ini
        UUID=00944838-9498-46f2-bd9e-e84e0eedd91a / ext4 errors=remount-ro,usrquota,grpquota 0 1
        ```

        *(Jangan* ubah `UUID` atau `/dev/sda1` yang sudah *ada di sistem Anda. Hanya tambahkan opsi kuota setelah opsi mount yang ada.)*

    * **Simpan dan keluar dari `nano`:** Tekan `Ctrl+O`, `Enter`, lalu `Ctrl+X`.

4.  **Reboot Server Anda (MANDATORI untuk kuota):**
    Perubahan pada `/etc/fstab` agar kuota berfungsi dengan benar **memerlukan *reboot***.

    ```bash
    sudo reboot
    ```

    *Tunggu* server *menyala kembali dan login lagi.*

5.  **Verifikasi dan Aktifkan Kuota Setelah Reboot:**
    Setelah *reboot*, Anda perlu memastikan sistem kuota aktif.

    ```bash
    sudo quotacheck -cvug /
    sudo quotaon -ug /
    sudo repquota -a # Untuk melihat laporan kuota (seharusnya masih kosong)
    ```

### **Bagian B: Persiapan Kode StreamHibV2 (Lakukan CUKUP SEKALI di REPOSITORI Anda)**

Anda perlu memodifikasi kode StreamHibV2 Anda agar mendukung multi-instans.

1.  **Modifikasi `app.py`:**
    Ubah definisi jalur file di `app.py` agar dinamis menggunakan `DIRECTORY_BASE` dan tambahkan konfigurasi logging.

    * **Buka `app.py` Anda.**

    * **Cari dan ubah bagian definisi jalur konfigurasi (di awal file, setelah import) menjadi:**

        ```python
        import os
        import logging # Pastikan ini sudah diimpor
        # ... impor lainnya ...

        # Dapatkan DIRECTORY_BASE dari variabel lingkungan atau gunakan default
        DIRECTORY_BASE = os.environ.get('STREAMHIB_BASE_DIR', os.path.dirname(os.path.abspath(__file__)))

        # Gunakan DIRECTORY_BASE untuk semua file konfigurasi dan data
        SESSION_FILE = os.path.join(DIRECTORY_BASE, 'sessions.json')
        LOCK_FILE = SESSION_FILE + '.lock'
        VIDEO_DIR = os.path.join(DIRECTORY_BASE, "videos")
        SERVICE_DIR = "/etc/systemd/system"
        USERS_FILE = os.path.join(DIRECTORY_BASE, 'users.json')
        DOMAIN_CONFIG_FILE = os.path.join(DIRECTORY_BASE, 'domain_config.json')

        # Pastikan direktori dibuat berdasarkan DIRECTORY_BASE
        os.makedirs(os.path.dirname(SESSION_FILE), exist_ok=True)
        os.makedirs(VIDEO_DIR, exist_ok=True)

        # Konfigurasi logging
        LOG_FILE_PATH = os.path.join(DIRECTORY_BASE, 'streamhib_instance.log')
        logging.basicConfig(
            level=logging.DEBUG,
            format='%(asctime)s [%(levelname)s] %(message)s',
            filename=LOG_FILE_PATH,
            filemode='a'
        )
        # ... sisa kode app.py ...
        ```

    * **Simpan perubahan pada `app.py` dan *commit* ke repositori GitHub Anda.**

2.  **Buat File `requirements.txt` (MANDATORI untuk skrip baru):**
    Karena skrip installer baru menggunakan `pip install -r requirements.txt`, Anda perlu membuat file ini di root repositori GitHub Anda.

    * **Buat file baru bernama `requirements.txt` di root repositori Anda.**

    * **Isi file tersebut dengan daftar dependensi berikut:**

        ```
        flask
        flask-socketio
        flask-cors
        filelock
        apscheduler
        pytz
        gunicorn
        eventlet
        paramiko
        scp
        ```

    * **Simpan** dan *commit* file `requirements.txt` ini **ke repositori GitHub Anda.**

### **Bagian C: Instalasi Setiap Instans Pengguna (Lakukan untuk SETIAP PENGGUNA)**

Ini adalah bagian di mana Anda membuat instans StreamHibV2 terpisah untuk setiap pengguna.

1.  **Unduh Skrip `install_user_instance.sh` yang Sudah Diperbarui:**

    * **Login kembali ke server Anda.**

    * **Unduh** skrip installer **terbaru:**

        ```bash
        wget https://raw.githubusercontent.com/gawenyikat/StreamHibV2/main/install_streamhib.sh
        chmod +x install_streamhib.sh
        
        ```

        *(Pastikan* Anda mendapatkan versi terbaru dari skrip ini yang *mengotomatiskan kuota dan user sistem).*

2.  **Pilih Nama Instans dan Port Unik:**
    Untuk server Netcup Anda, Anda akan membuat 8 instans. Contoh:

    * Pengguna 1: `user1`, Port `5001`

    * Pengguna 2: `user2`, Port `5002`

    * ...

    * Pengguna 8: `user8`, Port `5008`

3.  **Jalankan Skrip Instalasi untuk Setiap Instans:**
    Untuk setiap pengguna, jalankan perintah ini (ganti `<nama_instans>` dan `<port_instans>`):

    ```bash
    sudo bash install_streamhib.sh utama 5000
    
    ```

    **Contoh untuk Pengguna 1:**

    ```bash
    sudo bash install_user_instance.sh user1 5001
    
    ```

    **Contoh untuk Pengguna 2:**

    ```bash
    sudo bash install_user_instance.sh user2 5002
    
    ```

    Ulangi untuk semua pengguna yang Anda inginkan. Skrip ini akan:

    * Membuat direktori `/root/StreamHibV2-userX`.

    * Membuat user sistem unik (`streamhib_userX`) dan menetapkan kuota 30GB/35GB untuknya.

    * Menginstal StreamHibV2 di direktori tersebut.

    * Mengatur layanan `systemd` (`streamhibv2-userX.service`) untuk berjalan di bawah user sistem baru dan di port yang ditentukan.

    * Mencoba memulai layanan.

### **Bagian D: Konfigurasi Setelah Instalasi (Lakukan untuk SETIAP INSTANS)**

Setelah semua instans terinstal, ada beberapa langkah konfigurasi dan verifikasi.

1.  **Verifikasi Layanan Berjalan:**
    Setelah menjalankan skrip untuk setiap instans, tunggu sekitar 10-20 detik, lalu periksa status layanan:

    ```bash
    sudo systemctl status streamhibv2-<nama_instans>.service
    ```

    Pastikan statusnya `active (running)`. Jika `failed`, periksa log aplikasi untuk detail error:

    ```bash
    sudo tail -f /root/StreamHibV2-<nama_instans>/gunicorn_stderr.log
    ```

2.  **Buat Akun Pengguna Pertama di Panel StreamHibV2:**
    Untuk setiap instans, akses panelnya di browser:
    `http://<IP_SERVER_ANDA>:<port_instans>` (misal `http://192.168.1.100:5001`)
    Karena ini adalah instalasi baru, Anda akan diarahkan ke halaman registrasi. Buat akun pengguna pertama untuk instans tersebut.

3.  **Atur Domain Unik (Opsional, tapi Direkomendasikan):**
    Ini akan membuat akses lebih profesional (`user1.domainanda.com` daripada `IP:port`).

    * **Di penyedia DNS Anda:** Buat catatan `A` untuk setiap subdomain yang menunjuk ke **IP publik server Anda**.
        Contoh: `user1.domainanda.com` -> `IP_SERVER_ANDA`

    * **Di panel admin StreamHibV2 untuk setiap instans:**

        * Akses panel admin: `http://<IP_SERVER_ANDA>:<port_instans>/admin` (login: `admin` / `streamhib2025`).

        * Masuk ke menu **Pengaturan Domain**.

        * Masukkan domain unik untuk instans tersebut (misal `user1.domainanda.com`).

        * Pilih "Enable SSL" (sangat direkomendasikan).

        * Klik "Setup Domain". Ulangi untuk setiap instans.

4.  **Verifikasi Kuota Disk di UI:**
    Login ke panel StreamHibV2 setiap pengguna (melalui IP:Port atau domain uniknya). Di bagian Dashboard, Anda akan melihat "Penggunaan Disk". Nilai "Total" seharusnya mencerminkan kuota yang Anda tetapkan (misal 30GB), bukan total disk server.

## 🔍 Perintah Tambahan (per Instans)

Untuk mengelola instans spesifik, gunakan nama layanan `systemd` yang unik (`streamhibv2-<username_instans>.service`).

* **Cek status instans:**
    `sudo systemctl status streamhibv2-<username_instans>.service`

* **Stop Service instans:**
    `sudo systemctl stop streamhibv2-<username_instans>.service`

* **Restart Service instans:**
    `sudo systemctl restart streamhibv2-<username_instans>.service`

* **Lihat log service:**
    `journalctl -u streamhibv2-<username_instans>.service -f`

* **Lihat log aplikasi (lebih detail):**
    `tail -f /root/StreamHibV2-<nama_instans>/gunicorn_stderr.log`

## 🛠 Troubleshooting

* **Layanan `systemd` gagal memulai dengan `status=217/USER`:**
    Ini seharusnya sudah diatasi oleh skrip baru yang menghapus baris `User=root` dari definisi layanan `systemd` dan mengandalkan `systemd` untuk menjalankan sebagai `root` secara *default*. Jika Anda mencoba menggunakan user non-root unik, pastikan user tersebut sudah dibuat dengan `adduser --system` dan namanya sesuai di file layanan.

* **Error `pip install -r requirements.txt`:**
    Pastikan Anda telah membuat file `requirements.txt` di root repositori GitHub Anda dan sudah meng-*commit*-nya.
