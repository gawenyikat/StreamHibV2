# StreamHib V2 - Multi-User Installation Guide (FIXED)

> **Tanggal**: 06/07/2025 (Fixed Version)  
> **Status**: Production Ready  
> **Fungsi**: Platform streaming multi-user dengan isolasi user dan kuota disk

## ✨ Fitur Utama (Fixed)

* ✅ **Multi-User Support**: Beberapa user di satu server dengan isolasi penuh
* ✅ **Kuota Disk per User**: Pembatasan storage yang benar-benar berfungsi  
* ✅ **SystemD Service**: Service yang stabil dan auto-start
* ✅ **User Isolation**: Setiap user memiliki environment terpisah
* ✅ **Port Management**: Automatic port assignment untuk setiap user
* ✅ **Security**: Proper user permissions dan security hardening

## 🧱 Prasyarat

* Server Debian 11+ atau Ubuntu 20.04+
* Akses root atau sudo
* Minimal 4GB RAM untuk multiple users
* Storage yang cukup untuk semua user (quota akan dibatasi per user)

## 🚀 Instalasi

### Method 1: Install User Tunggal

```bash
# Download script yang sudah diperbaiki
wget https://raw.githubusercontent.com/gawenyikat/StreamHibV2/main/install_streamhib_fixed.sh
chmod +x install_streamhib_fixed.sh

# Install user dengan quota custom
sudo bash install_streamhib_fixed.sh user1 5001 30  # user1, port 5001, 30GB
sudo bash install_streamhib_fixed.sh user2 5002 20  # user2, port 5002, 20GB
```

### Method 2: Install Multiple Users (Batch)

```bash
# Download script batch installer
wget https://raw.githubusercontent.com/gawenyikat/StreamHibV2/main/install_multiple_users.sh
chmod +x install_multiple_users.sh

# Jalankan installer interaktif
sudo bash install_multiple_users.sh
```

**Contoh batch install:**
- Pilih option 2 (batch)
- Masukkan: 5 users, prefix "user", starting port 5001, quota 25GB
- Akan membuat: user1:5001, user2:5002, user3:5003, user4:5004, user5:5005

### Method 3: Install dengan Konfigurasi Custom

```bash
sudo bash install_multiple_users.sh
# Pilih option 3, lalu masukkan:
# user_premium:5001:50
# user_basic:5002:20  
# user_trial:5003:10
# done
```

## 🔍 Monitoring dan Management

### Cek Status Semua User

```bash
# Download status checker
wget https://raw.githubusercontent.com/gawenyikat/StreamHibV2/main/check_streamhib_status.sh
chmod +x check_streamhib_status.sh

# Jalankan status check
bash check_streamhib_status.sh
```

### Perintah Manual

```bash
# Cek semua service StreamHib
systemctl list-units --type=service | grep streamhib-

# Cek status user tertentu
systemctl status streamhib-user1.service

# Cek kuota semua user
repquota -a

# Cek kuota user tertentu  
quota -u streamhib_user1

# Restart user tertentu
systemctl restart streamhib-user1.service

# Lihat log user tertentu
journalctl -u streamhib-user1.service -f
```

## 📁 Struktur Direktori

```
/opt/streamhib/
├── user1/
│   └── StreamHibV2/
│       ├── venv/
│       ├── videos/
│       ├── logs/
│       └── app.py
├── user2/
│   └── StreamHibV2/
│       ├── venv/
│       ├── videos/
│       ├── logs/
│       └── app.py
└── ...
```

## 🔐 Security Features

* **User Isolation**: Setiap user memiliki system user terpisah
* **Directory Permissions**: Strict permissions per user directory
* **SystemD Security**: NoNewPrivileges, PrivateTmp, ProtectSystem
* **Network Isolation**: Setiap user bind ke port terpisah
* **Quota Enforcement**: Hard limit storage per user

## 🛠 Troubleshooting

### Service Tidak Berjalan

```bash
# Cek status detail
systemctl status streamhib-user1.service

# Cek log error
journalctl -u streamhib-user1.service -n 50

# Restart service
systemctl restart streamhib-user1.service
```

### Kuota Tidak Aktif

```bash
# Cek apakah kuota aktif di sistem
mount | grep quota

# Jika belum aktif, reboot server
sudo reboot

# Setelah reboot, cek lagi
repquota -a
```

### Port Tidak Dapat Diakses

```bash
# Cek apakah port terbuka
netstat -tlnp | grep :5001

# Cek firewall
ufw status

# Test koneksi lokal
curl http://localhost:5001
```

### Permission Issues

```bash
# Fix ownership jika ada masalah
sudo chown -R streamhib_user1:streamhib_user1 /opt/streamhib/user1/

# Restart service setelah fix permission
sudo systemctl restart streamhib-user1.service
```

## 📊 Monitoring Quota Usage

```bash
# Lihat penggunaan quota real-time
watch -n 5 'repquota -a | grep streamhib_'

# Alert jika user mendekati limit
for user in $(ls /opt/streamhib/); do
    usage=$(quota -u streamhib_$user | tail -1 | awk '{print $3}')
    limit=$(quota -u streamhib_$user | tail -1 | awk '{print $4}')
    if [ $usage -gt $((limit * 80 / 100)) ]; then
        echo "WARNING: User $user menggunakan lebih dari 80% quota"
    fi
done
```

## 🔄 Backup dan Restore

### Backup User Data

```bash
# Backup satu user
tar -czf user1_backup_$(date +%Y%m%d).tar.gz -C /opt/streamhib user1/

# Backup semua user
tar -czf all_users_backup_$(date +%Y%m%d).tar.gz -C /opt streamhib/
```

### Restore User Data

```bash
# Stop service dulu
systemctl stop streamhib-user1.service

# Restore data
tar -xzf user1_backup_20250106.tar.gz -C /opt/streamhib/

# Fix ownership
chown -R streamhib_user1:streamhib_user1 /opt/streamhib/user1/

# Start service
systemctl start streamhib-user1.service
```

## 🌐 Domain Setup (Optional)

Untuk setup domain per user:

```bash
# Setup subdomain untuk setiap user
# user1.yourdomain.com -> IP:5001
# user2.yourdomain.com -> IP:5002

# Konfigurasi nginx reverse proxy
sudo nano /etc/nginx/sites-available/streamhib-users

# Contoh config:
server {
    listen 80;
    server_name user1.yourdomain.com;
    location / {
        proxy_pass http://localhost:5001;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}
```

## ✅ Verifikasi Instalasi

Setelah instalasi, pastikan:

1. ✅ Service berjalan: `systemctl status streamhib-user1.service`
2. ✅ Port accessible: `curl http://localhost:5001`  
3. ✅ Quota aktif: `quota -u streamhib_user1`
4. ✅ Directory permissions benar: `ls -la /opt/streamhib/user1/`
5. ✅ Firewall configured: `ufw status`

## 🎯 Akses User

Setiap user dapat diakses di:
- **user1**: `http://YOUR_SERVER_IP:5001`
- **user2**: `http://YOUR_SERVER_IP:5002`  
- **user3**: `http://YOUR_SERVER_IP:5003`
- dst...

## 📈 Scaling

Untuk menambah user baru setelah instalasi awal:

```bash
# Install user baru kapan saja
sudo bash install_streamhib_fixed.sh user_new 5010 25
```

## 🔧 Maintenance

```bash
# Update semua user ke versi terbaru
for user in $(ls /opt/streamhib/); do
    echo "Updating $user..."
    systemctl stop streamhib-$user.service
    cd /opt/streamhib/$user/StreamHibV2
    git pull
    systemctl start streamhib-$user.service
done
```

---

## 🎉 Selesai!

StreamHib V2 Multi-User siap digunakan dengan:
- ✅ Isolasi user yang benar
- ✅ Kuota disk yang berfungsi  
- ✅ SystemD service yang stabil
- ✅ Security hardening
- ✅ Easy management tools

**Support**: Jika ada masalah, gunakan script `check_streamhib_status.sh` untuk diagnosis.