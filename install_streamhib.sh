#!/bin/bash

# StreamHib V2 - Installer Script untuk Instans Pengguna
# Tanggal: 06/07/2025 (Diperbarui)
# Fungsi: Instalasi instans StreamHib V2 baru dengan konfigurasi unik untuk setiap pengguna,
#         termasuk user sistem khusus dan pengaturan kuota disk otomatis.

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
    exit 1 # Keluar dari skrip jika terjadi error
}

# Fungsi untuk mengecek apakah command berhasil
check_command() {
    if [ $? -eq 0 ]; then
        print_success "$1"
    else
        print_error "Gagal: $1"
    fi
}

# Header
echo -e "${GREEN}"
echo "=================================================="
echo "    StreamHib V2 - Auto Installer Instans Pengguna"
echo "    Tanggal: 06/07/2025"
echo "    Platform: Debian 11 (Ubuntu Compatible)"
echo "    Fitur: Multi-Instans, Domain Support, Kuota Disk (via OS)"
echo "=================================================="
echo -e "${NC}"

# Cek apakah running sebagai root
if [ "$EUID" -ne 0 ]; then
    print_error "Skrip ini harus dijalankan sebagai root!"
    print_status "Gunakan: sudo bash install_user_instance.sh <username_instans> <port_instans>"
fi

# ====================================================================
# INPUT: Menerima argumen untuk nama pengguna dan port
# ====================================================================
INSTANCE_USERNAME=$1
INSTANCE_PORT=$2

if [ -z "$INSTANCE_USERNAME" ] || [ -z "$INSTANCE_PORT" ]; then
    print_error "Penggunaan: sudo bash install_user_instance.sh <username_instans> <port_instans>"
    print_status "Contoh: sudo bash install_user_instance.sh user_budi 5001"
fi

# ====================================================================
# DEFINISI VARIABEL JALUR DAN NAMA
# ====================================================================
INSTANCE_DIR="/root/StreamHibV2-${INSTANCE_USERNAME}"
SERVICE_NAME="streamhibv2-${INSTANCE_USERNAME}.service"
USER_SYS="streamhib_${INSTANCE_USERNAME}" # Nama user sistem unik untuk instans ini

print_status "Memulai instalasi StreamHib V2 untuk pengguna: ${INSTANCE_USERNAME} di port: ${INSTANCE_PORT}"

# ====================================================================
# BAGIAN GLOBAL: Persiapan Sistem (Jalankan Sekali per Server)
# ====================================================================

# 1. Update sistem dan Install dependensi dasar
print_status "Memastikan dependensi dasar sistem terinstal (ini mungkin butuh waktu)..."
apt update && apt upgrade -y && apt dist-upgrade -y
check_command "Update sistem"

apt install -y python3 python3-pip python3-venv ffmpeg git curl wget sudo ufw nginx certbot python3-certbot-nginx quota
check_command "Install dependensi dasar sistem dan quota"

pip3 install gdown paramiko scp
check_command "Install pustaka Python global"

# 2. Otomatisasi Penyiapan Kuota Disk (Jika belum aktif di fstab)
print_status "Mengecek dan mengaktifkan kuota disk di /etc/fstab (jika belum)..."

awk -v userq=",usrquota,grpquota" '
$2 == "/" && $3 == "ext4" {
    if ($4 !~ /usrquota/ && $4 !~ /grpquota/) {
        $4 = $4 userq;
    }
}
{ print }' /etc/fstab > /tmp/fstab.new
mv /tmp/fstab.new /etc/fstab
check_command "Modifikasi /etc/fstab untuk kuota"

print_warning "Perubahan /etc/fstab telah dilakukan. Kuota mungkin tidak sepenuhnya aktif sampai server di-REBOOT."
print_warning "Anda bisa me-reboot sekarang atau melanjutkan instalasi. Jika melanjutkan, kuota akan aktif setelah reboot berikutnya."

rm -f /aquota.user /aquota.group || true

print_status "Mencoba remount / ..."
mount -o remount / || true
check_command "Remount partisi root"

if [ ! -f /aquota.user ] || [ ! -f /aquota.group ]; then
    print_status "File kuota belum ada. Membuat file kuota dengan format vfsv1..."
    quotacheck -cvugm -F vfsv1 /
    check_command "Buat file kuota dengan quotacheck -F vfsv1"
else
    print_status "File kuota sudah ada. Melewati pembuatan file kuota."
fi

quotaon -ug / || print_warning "Quotaon gagal; kemungkinan butuh reboot agar quota aktif penuh"
check_command "Aktifkan quota dengan quotaon"

print_status "Kuota disk diaktifkan. Anda bisa cek dengan: repquota -a"

# ====================================================================
# BAGIAN PER INSTANS: Instalasi Aplikasi dan Konfigurasi Unik
# ====================================================================

# 3. Buat direktori aplikasi dan clone repository
print_status "Mengunduh StreamHib V2 ke ${INSTANCE_DIR}..."
if [ -d "${INSTANCE_DIR}" ]; then
    print_warning "Direktori ${INSTANCE_DIR} sudah ada, menghapus..."
    rm -rf "${INSTANCE_DIR}"
fi
git clone https://github.com/gawenyikat/StreamHibV2.git "${INSTANCE_DIR}"
check_command "Clone repository ke ${INSTANCE_DIR}"

cd "${INSTANCE_DIR}"

# 4. Buat user sistem khusus dan grup untuk instans ini
print_status "Membuat grup sistem '${USER_SYS}' (jika belum ada)..."
if ! getent group "$USER_SYS" >/dev/null; then
    addgroup --system "$USER_SYS"
    check_command "Buat grup sistem '$USER_SYS'"
else
    print_status "Grup sistem '$USER_SYS' sudah ada. Melanjutkan."
fi

print_status "Membuat user sistem '${USER_SYS}' (jika belum ada) dan menambahkannya ke grupnya..."
if ! id -u "$USER_SYS" >/dev/null 2>&1; then
    useradd --system --no-create-home -g "$USER_SYS" "$USER_SYS"
    check_command "Buat user sistem '$USER_SYS'"
else
    print_status "User sistem '$USER_SYS' sudah ada. Melanjutkan."
fi

# 5. Set permission direktori ke user sistem khusus
print_status "Mengatur kepemilikan direktori '${INSTANCE_DIR}' ke user '${USER_SYS}'..."
chown -R "$USER_SYS":"$USER_SYS" "$INSTANCE_DIR"
check_command "Set kepemilikan direktori"

# 6. Buat virtual environment
print_status "Membuat virtual environment di ${INSTANCE_DIR}/venv..."
python3 -m venv "${INSTANCE_DIR}/venv"
check_command "Buat virtual environment"

# 7. Aktivasi venv dan install dependensi Python di dalam venv
print_status "Menginstall dependensi Python di dalam virtual environment..."
source "${INSTANCE_DIR}/venv/bin/activate"
pip install flask flask-socketio flask-cors filelock apscheduler pytz gunicorn eventlet paramiko scp
check_command "Install dependensi Python di venv"
deactivate # Keluar dari virtual environment

# 8. Buat direktori 'videos', 'static', 'templates' (jika belum ada)
print_status "Memastikan direktori 'videos', 'static', 'templates' ada..."
mkdir -p videos static templates
check_command "Buat direktori 'videos', 'static', 'templates'"

# 9. Buat file favicon.ico dummy jika tidak ada
if [ ! -f "static/favicon.ico" ]; then
    print_status "Membuat favicon dummy..."
    touch static/favicon.ico
fi

# 10. Buat file logo dummy jika tidak ada
if [ ! -f "static/logostreamhib.png" ]; then
    print_status "Membuat logo dummy..."
    touch static/logostreamhib.png
fi

# 11. Setup firewall untuk port instans ini
print_status "Mengkonfigurasi firewall untuk port ${INSTANCE_PORT}..."
ufw allow "${INSTANCE_PORT}/tcp" comment "StreamHibV2 ${INSTANCE_USERNAME} Access"
ufw allow 22/tcp comment 'SSH Access'
ufw allow 80/tcp comment 'HTTP Access for Nginx'
ufw allow 443/tcp comment 'HTTPS Access for Nginx'
ufw --force enable
check_command "Konfigurasi firewall"

# 12. Buat systemd service unik untuk instans ini
print_status "Membuat systemd service ${SERVICE_NAME}..."
cat > "/etc/systemd/system/${SERVICE_NAME}" << EOF
[Unit]
Description=StreamHib Flask Service for ${INSTANCE_USERNAME} (Port ${INSTANCE_PORT})
After=network.target

[Service]
Environment="STREAMHIB_BASE_DIR=${INSTANCE_DIR}"
# PENTING: Baris User dan Group DIHAPUS agar service berjalan sebagai root
# agar memiliki izin untuk mengelola service systemd lainnya di /etc/systemd/system.
# User=${USER_SYS}
# Group=${USER_SYS}
ExecStart=/bin/bash -c "cd ${INSTANCE_DIR} && source venv/bin/activate && ${INSTANCE_DIR}/venv/bin/gunicorn --worker-class eventlet -w 1 -b 0.0.0.0:${INSTANCE_PORT} app:app"
ExecReload=/bin/bash -c "kill -HUP \$MAINPID"
Restart=always
TimeoutStartSec=120

StandardOutput=append:${INSTANCE_DIR}/gunicorn_stdout.log
StandardError=append:${INSTANCE_DIR}/gunicorn_stderr.log

[Install]
WantedBy=multi-user.target
EOF
check_command "Buat systemd service ${SERVICE_NAME}"

# 13. Reload systemd dan enable service
print_status "Mengaktifkan service ${SERVICE_NAME}..."
systemctl daemon-reload
sleep 1
systemctl enable "${SERVICE_NAME}"
check_command "Enable service ${SERVICE_NAME}"

# 14. Start service
print_status "Memulai StreamHib V2 untuk ${INSTANCE_USERNAME}..."
sleep 2
systemctl start "${SERVICE_NAME}"
check_command "Start service ${SERVICE_NAME}"

# 15. Atur kuota default 30GB/35GB untuk user instans
print_status "Mengatur kuota disk untuk user sistem '${USER_SYS}'..."
SOFT_LIMIT_KB=31457280  # 30GB in KB (30 * 1024 * 1024)
HARD_LIMIT_KB=36700160  # 35GB in KB (35 * 1024 * 1024)
DEVICE=$(df / | tail -1 | awk '{print $1}') # Dapatkan nama device (misal /dev/sda1)

# Menggunakan setquota secara langsung, yang lebih cocok untuk otomatisasi non-interaktif
# Format: setquota -u <username> <soft_blocks> <hard_blocks> <soft_inodes> <hard_inodes> <filesystem>
setquota -u "$USER_SYS" "$SOFT_LIMIT_KB" "$HARD_LIMIT_KB" 0 0 "$DEVICE"
check_command "Atur kuota disk untuk user '${USER_SYS}' menggunakan setquota"

# Pastikan kuota diaktifkan untuk filesystem (opsional, tapi baik untuk memastikan)
quotaon -ug "$DEVICE" || true
print_status "Memastikan kuota aktif di ${DEVICE}"

# 16. Cek status service
sleep 3
if systemctl is-active --quiet "${SERVICE_NAME}"; then
    print_success "StreamHib V2 untuk ${INSTANCE_USERNAME} berhasil berjalan!"
else
    print_warning "Service ${SERVICE_NAME} mungkin belum siap, cek status dengan: systemctl status ${SERVICE_NAME}"
fi

# ====================================================================
# TAMPILAN INFORMASI AKHIR
# ====================================================================
echo -e "${GREEN}"
echo "=================================================="
echo "    INSTALASI INSTANS SELESAI!"
echo "=================================================="
echo -e "${NC}"

SERVER_IP=$(curl -s ifconfig.me 2>/dev/null || curl -s ipinfo.io/ip 2>/dev/null || hostname -I | awk '{print $1}')

print_success "StreamHib V2 untuk ${INSTANCE_USERNAME} berhasil diinstall!"
echo ""
print_status "Informasi Akses untuk ${INSTANCE_USERNAME}:"
echo "  URL: http://${SERVER_IP}:${INSTANCE_PORT}"
print_status "  Port: ${INSTANCE_PORT}"
echo ""
print_status "Direktori instalasi: ${INSTANCE_DIR}"
print_status "User sistem untuk instans ini: ${USER_SYS}"
echo ""
print_status "Fitur Baru untuk Instans Ini:"
print_status "  ✅ Sistem Migrasi Seamless (data instans ini)"
print_status "  ✅ Recovery Otomatis (untuk instans ini)"
print_status "  ✅ Domain Support dengan SSL (via panel admin instans ini)"
print_status "  ✅ Nginx Reverse Proxy (global, dikonfigurasi via panel admin instans ini)"
print_status "  ✅ Kuota Disk 30GB/35GB untuk user '${USER_SYS}'"
echo ""
print_status "Setup Domain (Opsional) untuk ${INSTANCE_USERNAME}:"
print_status "  1. Arahkan domain unik (misal ${INSTANCE_USERNAME}.domainanda.com) ke IP: ${SERVER_IP}"
print_status "  2. Tunggu propagasi DNS (5-15 menit)."
if [[ "$SERVER_IP" =~ ":" ]]; then # Cek jika IP adalah IPv6
    print_status "  3. Akses panel StreamHib untuk instans ini: http://[${SERVER_IP}]:${INSTANCE_PORT}"
else
    print_status "  3. Akses panel StreamHib untuk instans ini: http://${SERVER_IP}:${INSTANCE_PORT}"
fi
print_status "  4. Login ke panel admin (default: admin / streamhib2025)."
print_status "  5. Masuk menu 'Pengaturan Domain'."
print_status "  6. Setup domain Anda dengan SSL otomatis."
echo ""
print_status "Perintah Berguna untuk instans ini:"
print_status "  Status service: systemctl status ${SERVICE_NAME}"
print_status "  Stop service: systemctl stop ${SERVICE_NAME}"
print_status "  Start service: systemctl start ${SERVICE_NAME}"
print_status "  Restart service: systemctl restart ${SERVICE_NAME}"
print_status "  Lihat log service: journalctl -u ${SERVICE_NAME} -f"
print_status "  Lihat log aplikasi: tail -f ${INSTANCE_DIR}/gunicorn_stderr.log"
print_status "  Lihat log recovery: journalctl -u ${SERVICE_NAME} -f | grep RECOVERY"
print_status "  Lihat log domain: journalctl -u ${SERVICE_NAME} -f | grep DOMAIN"
echo ""
print_status "Direktori instalasi: ${INSTANCE_DIR}"
echo ""

print_status "Mengecek koneksi ke port ${INSTANCE_PORT}..."
if curl -s --connect-timeout 5 "http://localhost:${INSTANCE_PORT}" > /dev/null; then
    print_success "Server dapat diakses di http://${SERVER_IP}:${INSTANCE_PORT}"
else
    print_warning "Server mungkin masih starting up. Tunggu beberapa detik dan coba akses."
fi

echo ""
print_success "Instalasi StreamHib V2 untuk ${INSTANCE_USERNAME} selesai! Selamat menggunakan!"
echo -e "${YELLOW}Jangan lupa untuk membuat akun pertama di halaman register untuk instans ini.${NC}"
echo -e "${BLUE}Untuk setup domain, login ke panel admin instans ini dan masuk menu 'Pengaturan Domain'.${NC}"
