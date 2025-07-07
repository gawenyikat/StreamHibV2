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

* Server berbasis Debian (Debian 11+, Ubuntu 20.04+).
* Akses root atau user dengan sudo.
* SSH key aktif (khusus Biznet, jika relevan untuk Anda).
* Port yang akan digunakan untuk setiap instans harus terbuka untuk publik (misal 5000, 5001, 5002, dst.).
* Domain (opsional, untuk akses yang lebih profesional dan unik per pengguna).

---

### 🚀 Instalasi Instans Pengguna (Disarankan)

Gunakan skrip `install_streamhib.sh` untuk menginstal setiap instans StreamHibV2. Ini adalah metode yang direkomendasikan untuk satu pengguna atau banyak pengguna di satu server.

#### 1. Persiapan Awal Server (Lakukan CUKUP SEKALI per SERVER FISIK)

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

    * **Modifikasi `fstab` secara otomatis dengan `awk`:**
        Ini akan menambahkan opsi kuota (`usrquota,grpquota`) ke baris partisi root (`/`) jika belum ada.

        ```bash
        sudo awk -v userq=",usrquota,grpquota" '
        $2 == "/" && $3 == "ext4" {
            if ($4 !~ /usrquota/ && $4 !~ /grpquota/) {
                $4 = $4 userq;
            }
        }
        { print }' /etc/fstab > /tmp/fstab.new && sudo mv /tmp/fstab.new /etc/fstab
        ```

    * **Hapus file kuota lama (opsional, untuk memastikan konsistensi):**
        ```bash
        sudo rm -f /aquota.user /aquota.group || true
        ```

    * **Reboot Server Anda (MANDATORI untuk kuota berfungsi penuh):**
        Perubahan pada `/etc/fstab` agar kuota berfungsi dengan benar **memerlukan *reboot***.

        ```bash
        sudo reboot
        ```

        *Tunggu* server *menyala kembali dan login lagi.*

4.  **Verifikasi dan Aktifkan Kuota Setelah Reboot:**
    Setelah *reboot*, Anda perlu memastikan sistem kuota aktif.

    ```bash
    sudo quotacheck -cvugm -F ext4 /
    sudo quotaon -ug /
    sudo repquota -a # Untuk melihat laporan kuota (seharusnya masih kosong)
    ```

#### 2. Unduh Skrip Installer Instans

Unduh skrip `install_streamhib.sh` ke server Anda.

```bash
wget [https://raw.githubusercontent.com/gawenyikat/StreamHibV2/main/install_streamhib.sh](https://raw.githubusercontent.com/gawenyikat/StreamHibV2/main/install_streamhib.sh)
chmod +x install_streamhib.sh
