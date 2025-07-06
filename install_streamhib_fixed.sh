#!/bin/bash

# StreamHib V2 - Fixed Multi-User Installer Script
# Tanggal: 06/07/2025 (Fixed Version)
# Fungsi: Instalasi instans StreamHib V2 dengan sistem kuota yang benar dan multi-user support

set -e # Keluar jika ada kesalahan

# Warna untuk output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Fungsi untuk print dengan warna
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Fungsi untuk mengecek apakah command berhasil
check_command() {
    if [ $? -eq 0 ]; then
        print_success "$1"
    else
        print_error "Gagal: $1"
        exit 1
    fi
}

# Header
echo -e "${GREEN}"
echo "=================================================="
echo "    StreamHib V2 - Fixed Multi-User Installer"
echo "    Tanggal: 06/07/2025"
echo "    Platform: Debian 11 (Ubuntu Compatible)"
echo "    Fitur: Multi-Instans, Kuota Disk, User Isolation"
echo "=================================================="
echo -e "${NC}"

# Cek apakah running sebagai root
if [ "$EUID" -ne 0 ]; then
    print_error "Skrip ini harus dijalankan sebagai root!"
    print_status "Gunakan: sudo bash install_streamhib_fixed.sh <username_instans> <port_instans> [quota_gb]"
    exit 1
fi

# ====================================================================
# INPUT: Menerima argumen untuk nama pengguna, port, dan kuota
# ====================================================================
INSTANCE_USERNAME=$1
INSTANCE_PORT=$2
QUOTA_GB=${3:-30}  # Default 30GB jika tidak disebutkan

if [ -z "$INSTANCE_USERNAME" ] || [ -z "$INSTANCE_PORT" ]; then
    print_error "Penggunaan: sudo bash install_streamhib_fixed.sh <username_instans> <port_instans> [quota_gb]"
    print_status "Contoh: sudo bash install_streamhib_fixed.sh user1 5001 20"
    print_status "Contoh: sudo bash install_streamhib_fixed.sh user2 5002 30"
    exit 1
fi

# ====================================================================
# DEFINISI VARIABEL JALUR DAN NAMA
# ====================================================================
INSTANCE_DIR="/opt/streamhib/${INSTANCE_USERNAME}"
SERVICE_NAME="streamhib-${INSTANCE_USERNAME}.service"
USER_SYS="streamhib_${INSTANCE_USERNAME}"

print_status "Memulai instalasi StreamHib V2 untuk: ${INSTANCE_USERNAME}"
print_status "Port: ${INSTANCE_PORT}, Kuota: ${QUOTA_GB}GB"

# ====================================================================
# BAGIAN 1: PERSIAPAN SISTEM (Jalankan sekali per server)
# ====================================================================

print_status "=== TAHAP 1: PERSIAPAN SISTEM ==="

# Update sistem dan install dependensi
print_status "Memperbarui sistem dan menginstall dependensi..."
apt update && apt upgrade -y
apt install -y python3 python3-pip python3-venv ffmpeg git curl wget sudo ufw nginx certbot python3-certbot-nginx quota quotatool
check_command "Install dependensi sistem"

# Install pustaka Python global
pip3 install gdown paramiko scp
check_command "Install pustaka Python global"

# ====================================================================
# BAGIAN 2: SETUP KUOTA DISK (Perbaikan)
# ====================================================================

print_status "=== TAHAP 2: SETUP KUOTA DISK ==="

# Cek apakah kuota sudah aktif
if ! grep -q "usrquota\|grpquota" /etc/fstab; then
    print_warning "Kuota belum aktif. Mengaktifkan kuota disk..."
    
    # Backup fstab
    cp /etc/fstab /etc/fstab.backup.$(date +%Y%m%d_%H%M%S)
    check_command "Backup /etc/fstab"
    
    # Tambahkan opsi kuota ke partisi root
    # Cari baris yang mengandung " / " dan tambahkan opsi kuota
    sed -i.bak '/[[:space:]]\/[[:space:]]/ {
        /usrquota/! {
            /grpquota/! {
                s/\([[:space:]]ext4[[:space:]]\+\)\([^[:space:]]*\)/\1\2,usrquota,grpquota/
            }
        }
    }' /etc/fstab
    check_command "Modifikasi /etc/fstab untuk kuota"
    
    print_warning "Perubahan fstab selesai. Melakukan remount..."
    
    # Coba remount
    mount -o remount / || print_warning "Remount gagal, lanjut dengan quotacheck"
    
    # Setup kuota
    quotacheck -cug / || print_warning "Quotacheck mungkin perlu reboot untuk bekerja sempurna"
    quotaon -ug / || print_warning "Quotaon mungkin perlu reboot untuk bekerja sempurna"
    
    print_warning "Kuota telah diaktifkan. Untuk hasil optimal, reboot server setelah semua instalasi selesai."
else
    print_status "Kuota sudah aktif di sistem"
    quotaon -ug / 2>/dev/null || print_warning "Kuota mungkin perlu direstart"
fi

# ====================================================================
# BAGIAN 3: BUAT USER SISTEM DAN DIREKTORI
# ====================================================================

print_status "=== TAHAP 3: SETUP USER DAN DIREKTORI ==="

# Buat direktori utama
mkdir -p "/opt/streamhib"
mkdir -p "${INSTANCE_DIR}"

# Buat user sistem dengan konfigurasi yang benar
if ! id "$USER_SYS" &>/dev/null; then
    print_status "Membuat user sistem: $USER_SYS"
    useradd --system --home-dir "${INSTANCE_DIR}" --create-home --shell /bin/bash "$USER_SYS"
    check_command "Buat user sistem $USER_SYS"
else
    print_status "User sistem $USER_SYS sudah ada"
fi

# Set kuota untuk user
print_status "Mengatur kuota ${QUOTA_GB}GB untuk user $USER_SYS"
QUOTA_KB=$((QUOTA_GB * 1024 * 1024))  # Convert GB to KB
QUOTA_SOFT_KB=$((QUOTA_KB * 90 / 100))  # 90% untuk soft limit

# Gunakan setquota yang lebih reliable
if command -v setquota >/dev/null 2>&1; then
    setquota -u "$USER_SYS" "$QUOTA_SOFT_KB" "$QUOTA_KB" 0 0 / || print_warning "Setquota gagal, mungkin perlu reboot"
    check_command "Set kuota untuk $USER_SYS"
else
    print_warning "setquota tidak tersedia, menggunakan edquota manual"
    # Fallback ke edquota
    (
        echo "Filesystem                   blocks       soft       hard     inodes     soft     hard"
        echo "/dev/$(df / | tail -1 | awk '{print $1}' | sed 's|/dev/||')              0    $QUOTA_SOFT_KB    $QUOTA_KB          0        0        0"
    ) | edquota -u "$USER_SYS" -f - || print_warning "Edquota gagal"
fi

# ====================================================================
# BAGIAN 4: CLONE DAN SETUP APLIKASI
# ====================================================================

print_status "=== TAHAP 4: SETUP APLIKASI ==="

# Clone repository ke direktori user
cd "${INSTANCE_DIR}"
if [ -d "StreamHibV2" ]; then
    print_warning "Direktori StreamHibV2 sudah ada, menghapus..."
    rm -rf StreamHibV2
fi

print_status "Clone repository StreamHibV2..."
git clone https://github.com/gawenyikat/StreamHibV2.git
check_command "Clone repository"

cd StreamHibV2

# Buat virtual environment
print_status "Membuat virtual environment..."
python3 -m venv venv
check_command "Buat virtual environment"

# Install dependensi Python
print_status "Install dependensi Python..."
source venv/bin/activate
pip install --upgrade pip
pip install flask flask-socketio flask-cors filelock apscheduler pytz gunicorn eventlet paramiko scp
check_command "Install dependensi Python"
deactivate

# Buat direktori yang diperlukan
mkdir -p videos static templates logs
touch static/favicon.ico
touch static/logostreamhib.png

# Set ownership ke user sistem
chown -R "$USER_SYS:$USER_SYS" "${INSTANCE_DIR}"
check_command "Set ownership direktori"

# ====================================================================
# BAGIAN 5: KONFIGURASI FIREWALL
# ====================================================================

print_status "=== TAHAP 5: KONFIGURASI FIREWALL ==="

ufw allow "${INSTANCE_PORT}/tcp" comment "StreamHib ${INSTANCE_USERNAME}"
ufw allow 22/tcp comment 'SSH Access'
ufw allow 80/tcp comment 'HTTP Nginx'
ufw allow 443/tcp comment 'HTTPS Nginx'
ufw --force enable
check_command "Konfigurasi firewall"

# ====================================================================
# BAGIAN 6: BUAT SYSTEMD SERVICE
# ====================================================================

print_status "=== TAHAP 6: SETUP SYSTEMD SERVICE ==="

cat > "/etc/systemd/system/${SERVICE_NAME}" << EOF
[Unit]
Description=StreamHib V2 Service for ${INSTANCE_USERNAME} (Port ${INSTANCE_PORT})
After=network.target

[Service]
Type=simple
User=${USER_SYS}
Group=${USER_SYS}
WorkingDirectory=${INSTANCE_DIR}/StreamHibV2
Environment="STREAMHIB_BASE_DIR=${INSTANCE_DIR}/StreamHibV2"
Environment="PATH=${INSTANCE_DIR}/StreamHibV2/venv/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
ExecStart=${INSTANCE_DIR}/StreamHibV2/venv/bin/gunicorn --worker-class eventlet -w 1 --bind 0.0.0.0:${INSTANCE_PORT} app:app
Restart=always
RestartSec=3
TimeoutStartSec=120
TimeoutStopSec=30

# Logging
StandardOutput=append:${INSTANCE_DIR}/StreamHibV2/logs/gunicorn.log
StandardError=append:${INSTANCE_DIR}/StreamHibV2/logs/gunicorn_error.log

# Security
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=${INSTANCE_DIR}

[Install]
WantedBy=multi-user.target
EOF

check_command "Buat systemd service ${SERVICE_NAME}"

# ====================================================================
# BAGIAN 7: START SERVICE
# ====================================================================

print_status "=== TAHAP 7: START SERVICE ==="

systemctl daemon-reload
check_command "Reload systemd daemon"

systemctl enable "${SERVICE_NAME}"
check_command "Enable service ${SERVICE_NAME}"

# Tunggu sebentar sebelum start
sleep 2

systemctl start "${SERVICE_NAME}"
check_command "Start service ${SERVICE_NAME}"

# Tunggu service siap
sleep 5

# Cek status service
if systemctl is-active --quiet "${SERVICE_NAME}"; then
    print_success "Service ${SERVICE_NAME} berjalan dengan baik!"
else
    print_warning "Service mungkin belum siap. Cek status: systemctl status ${SERVICE_NAME}"
    print_status "Log error: journalctl -u ${SERVICE_NAME} -n 20"
fi

# ====================================================================
# BAGIAN 8: VERIFIKASI DAN INFO AKHIR
# ====================================================================

print_status "=== TAHAP 8: VERIFIKASI ==="

# Cek kuota user
print_status "Verifikasi kuota user:"
quota -u "$USER_SYS" 2>/dev/null || print_warning "Quota belum aktif, mungkin perlu reboot"

# Cek koneksi
print_status "Mengecek koneksi ke port ${INSTANCE_PORT}..."
sleep 3
if curl -s --connect-timeout 10 "http://localhost:${INSTANCE_PORT}" > /dev/null; then
    print_success "Server dapat diakses di port ${INSTANCE_PORT}!"
else
    print_warning "Server belum dapat diakses. Tunggu beberapa detik atau cek log service."
fi

# ====================================================================
# TAMPILAN INFORMASI AKHIR
# ====================================================================

SERVER_IP=$(curl -s ifconfig.me 2>/dev/null || curl -s ipinfo.io/ip 2>/dev/null || hostname -I | awk '{print $1}')

echo -e "${GREEN}"
echo "=================================================="
echo "    INSTALASI SELESAI!"
echo "=================================================="
echo -e "${NC}"

print_success "StreamHib V2 untuk ${INSTANCE_USERNAME} berhasil diinstall!"
echo ""
print_status "Informasi Akses:"
echo "  URL: http://${SERVER_IP}:${INSTANCE_PORT}"
echo "  Port: ${INSTANCE_PORT}"
echo "  Kuota: ${QUOTA_GB}GB"
echo ""
print_status "Direktori: ${INSTANCE_DIR}/StreamHibV2"
print_status "User sistem: ${USER_SYS}"
print_status "Service: ${SERVICE_NAME}"
echo ""
print_status "Perintah berguna:"
echo "  Status: systemctl status ${SERVICE_NAME}"
echo "  Log: journalctl -u ${SERVICE_NAME} -f"
echo "  Stop: systemctl stop ${SERVICE_NAME}"
echo "  Start: systemctl start ${SERVICE_NAME}"
echo "  Restart: systemctl restart ${SERVICE_NAME}"
echo ""
print_status "Cek kuota: quota -u ${USER_SYS}"
echo ""

if ! systemctl is-active --quiet "${SERVICE_NAME}"; then
    print_warning "PERHATIAN: Service belum berjalan sempurna!"
    print_status "Coba: systemctl status ${SERVICE_NAME}"
    print_status "Log: journalctl -u ${SERVICE_NAME} -n 50"
fi

print_success "Instalasi selesai! Akses: http://${SERVER_IP}:${INSTANCE_PORT}"
echo -e "${YELLOW}Jangan lupa buat akun pertama di halaman register!${NC}"

if grep -q "usrquota\|grpquota" /etc/fstab && ! quota -u "$USER_SYS" &>/dev/null; then
    echo ""
    print_warning "REKOMENDASI: Reboot server untuk mengaktifkan kuota disk sepenuhnya:"
    print_status "sudo reboot"
fi