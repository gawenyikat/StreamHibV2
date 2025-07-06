Berikut adalah versi *README.md* yang sudah dirapikan dan diformat menggunakan gaya Markdown standar GitHub agar mudah dibaca dan langsung dapat di-*copy paste* ke dalam repositori GitHub:

---

````markdown
# 🎥 StreamHibV2

> **Tanggal Rilis:** 06 Juli 2025  
> **Status:** Bismillah, dalam tahap pengembangan  
> **Platform Manajemen Streaming Berbasis Flask + FFmpeg**

StreamHibV2 adalah platform manajemen live streaming berbasis Flask dan FFmpeg yang mendukung multi-instans pengguna dalam satu server dengan domain dan lingkungan terpisah. Cocok untuk digunakan di server Regxa, Contabo, Hetzner, dan Biznet.

---

## ✨ Fitur Utama

- ✅ Panel kontrol berbasis web (Flask)
- ✅ Integrasi WebSocket & FFmpeg
- ✅ Multi-Instans: Jalankan banyak salinan di satu server
- ✅ Instalasi per pengguna dengan script otomatis
- ✅ Autostart via systemd
- ✅ Transfer dan backup video dari server lama
- ✅ Recovery sesi dan jadwal otomatis
- ✅ Migration Wizard (1-klik migrasi)
- ✅ Dukungan domain unik + SSL otomatis
- ✅ Kuota disk per instans pengguna (via sistem OS)

---

## 🧱 Prasyarat Sistem

- OS: Debian (Contabo, Regxa, Hetzner, Biznet)
- Akses: Root atau sudo user
- SSH key aktif (untuk Biznet)
- Port publik terbuka (5000, 5001, dst.)
- (Opsional) Domain unik per instans

---

## 🚀 Instalasi Instans Pengguna

Gunakan `install_user_instance.sh` untuk membuat instans per pengguna.

### 1. Persiapan Awal (sekali per server)

```bash
sudo apt update && sudo apt upgrade -y && sudo apt dist-upgrade -y
sudo apt install -y python3 python3-pip python3-venv ffmpeg git curl wget sudo ufw nginx certbot python3-certbot-nginx gunicorn eventlet
sudo pip3 install gdown paramiko scp
````

### 2. Unduh Skrip Installer

```bash
wget https://raw.githubusercontent.com/gawenyikat/StreamHibV2/main/install_user_instance.sh
chmod +x install_user_instance.sh
```

### 3. Jalankan Installer per Instans

```bash
# Contoh:
sudo bash install_user_instance.sh budi 5001
sudo bash install_user_instance.sh ayu 5002
sudo bash install_user_instance.sh utama 5000  # instans utama
```

---

## 🌐 Setup Domain (Opsional)

### 1. Persiapan Domain

Tambahkan A record DNS:

```
budi.domainanda.com → IP_SERVER
ayu.domainanda.com  → IP_SERVER
```

Tunggu propagasi DNS (5–15 menit).

### 2. Konfigurasi via Web

* Akses instans: `http://IP_SERVER:5001`
* Login: `admin / streamhib2025`
* Masuk ke **Pengaturan Domain**
* Masukkan domain unik (mis: `budi.domainanda.com`)
* Centang SSL (jika ingin)
* Klik **Setup Domain**

---

## 🗄️ Manajemen Kuota Disk (Opsional)

### 1. Aktifkan Kuota Disk

```bash
sudo apt install quota -y
```

Edit `/etc/fstab`:

```fstab
UUID=xxxx / ext4 defaults,usrjquota=aquota.user,grpjquota=aquota.group,jqfmt=vfsv0 0 1
```

Lanjutkan:

```bash
sudo mount -o remount /
sudo quotacheck -cum /
sudo quotaon -ug /
```

### 2. Buat Pengguna Sistem per Instans

```bash
sudo adduser --system --no-create-home streamhib_budi
sudo chown -R streamhib_budi:streamhib_budi /root/StreamHibV2-budi
```

Edit file systemd:
`/etc/systemd/system/streamhibv2-budi.service`
Ubah:

```ini
User=streamhib_budi
```

Lalu:

```bash
sudo systemctl daemon-reload
sudo systemctl restart streamhibv2-budi.service
```

### 3. Atur Kuota

```bash
sudo edquota -u streamhib_budi
```

Contoh isi:

```
streamhib_budi /dev/sda1 30720000 35840000 0 0  # Soft: 30GB, Hard: 35GB
```

---

## 🔄 Migrasi Server

### 1. Setup Server Baru (Server B)

* Instal instans StreamHibV2 yang sama
* Pastikan port dan nama instans sama

### 2. Gunakan Migration Wizard

1. Login ke admin panel di server baru (`http://IP_BARU:PORT/admin`)
2. Masuk menu **Migration**
3. Isi data server lama (IP, username, password)
4. Klik **Test Connection**
5. Klik **Start Migration**
6. Setelah selesai, klik **Start Recovery**

### 3. File yang Ditransfer

* `sessions.json`
* `users.json`
* `domain_config.json`
* Semua video (mp4, avi, mov, mkv)

### 4. Update DNS

Perbarui catatan A untuk domain ke IP server baru.

### 5. Matikan Server Lama

Setelah semua stabil di server baru.

---

## 🔍 Perintah Tambahan (per Instans)

```bash
# Cek status
sudo systemctl status streamhibv2-budi.service

# Restart service
sudo systemctl restart streamhibv2-budi.service

# Stop service
sudo systemctl stop streamhibv2-budi.service

# Lihat log langsung
journalctl -u streamhibv2-budi.service -f

# Cek recovery log
journalctl -u streamhibv2-budi.service -f | grep RECOVERY

# Cek log domain
journalctl -u streamhibv2-budi.service -f | grep DOMAIN
```

### Jalankan Manual (tanpa systemd)

```bash
cd /root/StreamHibV2-budi
source venv/bin/activate
python -m flask run --host=0.0.0.0 --port=5001
```

---

## 🛠 Troubleshooting

### 1. Hetzner Read-Only

```bash
fsck -y /dev/sda1
reboot
```

### 2. gdown Error (Disk Penuh)

```bash
df -h
rm -rf /root/.cache/gdown/
```

### 3. Recovery Tidak Jalan

```bash
journalctl -u streamhibv2-budi.service -f | grep "Scheduler dimulai"
sudo systemctl restart streamhibv2-budi.service
```

Trigger recovery manual:

```bash
curl -X POST http://localhost:5001/api/recovery/manual \
     -H "Content-Type: application/json" \
     --cookie "session=your_session_cookie"
```

### 4. Sesi Tidak Pulih

```bash
ls -la /root/StreamHibV2-budi/videos/
cat /root/StreamHibV2-budi/sessions.json | jq '.active_sessions'
```

### 5. Domain Tidak Akses

```bash
nslookup domainanda.com
dig domainanda.com
nginx -t
systemctl status nginx
certbot certificates
tail -f /var/log/nginx/error.log
```

### 6. Migrasi Video Lama Manual

```bash
scp -r root@server_lama:/root/StreamHibV2-budi/videos /root/StreamHibV2-budi/
```

---

## ✅ Keunggulan StreamHibV2

* 🔄 **Zero Downtime Migration**
* 🧠 **Auto Recovery Sesi & Jadwal**
* 🌐 **Domain & SSL Otomatis**
* 📦 **Isolasi Data per Instans**
* 💾 **Kuota Disk per Pengguna**
* 🔍 **Log dan Monitoring per Instans**
* ⚙️ **Konfigurasi Fleksibel per Pengguna**

---

## 📌 Akses Aplikasi

* IP & Port: `http://<IP>:<PORT>`
* Domain: `https://<your-domain.com>`

---

💡 StreamHibV2 adalah solusi fleksibel untuk kebutuhan live streaming multi-user di satu server. Cocok untuk penyedia layanan hosting, kampus, komunitas, dan pemilik media mandiri.

```

---

Silakan paste langsung ke file `README.md` pada repositori GitHub Anda. Jika Anda ingin saya bantu *generate* file `.md` atau mengkonversi ke PDF juga, tinggal beri tahu saja.
```
