#!/bin/bash

# StreamHib V2 - Multiple Users Installer
# Script untuk install beberapa user sekaligus

set -e

# Warna untuk output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

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

# Header
echo -e "${GREEN}"
echo "=================================================="
echo "    StreamHib V2 - Multiple Users Installer"
echo "    Tanggal: 06/07/2025"
echo "=================================================="
echo -e "${NC}"

# Cek root
if [ "$EUID" -ne 0 ]; then
    print_error "Script ini harus dijalankan sebagai root!"
    exit 1
fi

# Konfigurasi default
DEFAULT_QUOTA=30
START_PORT=5000

# Fungsi untuk install satu user
install_user() {
    local username=$1
    local port=$2
    local quota=${3:-$DEFAULT_QUOTA}
    
    print_status "Installing user: $username on port $port with ${quota}GB quota"
    
    if ! bash install_streamhib_fixed.sh "$username" "$port" "$quota"; then
        print_error "Failed to install user: $username"
        return 1
    fi
    
    print_success "User $username installed successfully!"
    return 0
}

# Menu interaktif
echo "Pilih mode instalasi:"
echo "1. Install user tunggal"
echo "2. Install multiple users (batch)"
echo "3. Install dengan konfigurasi custom"
read -p "Pilihan (1-3): " choice

case $choice in
    1)
        read -p "Username: " username
        read -p "Port: " port
        read -p "Quota GB (default: $DEFAULT_QUOTA): " quota
        quota=${quota:-$DEFAULT_QUOTA}
        
        install_user "$username" "$port" "$quota"
        ;;
    
    2)
        read -p "Berapa user yang ingin diinstall? " num_users
        read -p "Prefix username (contoh: user): " prefix
        read -p "Starting port (default: $START_PORT): " start_port
        start_port=${start_port:-$START_PORT}
        read -p "Quota per user GB (default: $DEFAULT_QUOTA): " quota
        quota=${quota:-$DEFAULT_QUOTA}
        
        print_status "Installing $num_users users with prefix '$prefix'"
        
        for i in $(seq 1 $num_users); do
            username="${prefix}${i}"
            port=$((start_port + i - 1))
            
            print_status "Installing user $i of $num_users: $username"
            if install_user "$username" "$port" "$quota"; then
                echo "  ✓ $username installed on port $port"
            else
                echo "  ✗ $username failed"
            fi
            
            # Jeda antar instalasi
            sleep 2
        done
        ;;
    
    3)
        echo "Mode custom - masukkan konfigurasi manual"
        echo "Format: username:port:quota_gb"
        echo "Contoh: user1:5001:20"
        echo "Ketik 'done' untuk selesai"
        
        while true; do
            read -p "Config: " config
            if [ "$config" = "done" ]; then
                break
            fi
            
            IFS=':' read -r username port quota <<< "$config"
            if [ -z "$username" ] || [ -z "$port" ]; then
                print_error "Format salah! Gunakan: username:port:quota"
                continue
            fi
            
            quota=${quota:-$DEFAULT_QUOTA}
            install_user "$username" "$port" "$quota"
        done
        ;;
    
    *)
        print_error "Pilihan tidak valid!"
        exit 1
        ;;
esac

# Summary
echo ""
echo -e "${GREEN}=================================================="
echo "    INSTALASI SELESAI!"
echo "==================================================${NC}"

print_status "Daftar service yang terinstall:"
systemctl list-units --type=service | grep streamhib- || print_warning "Tidak ada service streamhib yang ditemukan"

echo ""
print_status "Untuk mengecek semua service:"
echo "  systemctl list-units --type=service | grep streamhib-"

echo ""
print_status "Untuk mengecek kuota semua user:"
echo "  repquota -a"

echo ""
print_warning "REKOMENDASI: Reboot server untuk mengaktifkan kuota disk sepenuhnya jika ini instalasi pertama"

print_success "Semua instalasi selesai!"