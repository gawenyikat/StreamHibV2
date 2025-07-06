#!/bin/bash

# StreamHib V2 - Status Checker
# Script untuk mengecek status semua instans StreamHib

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

echo -e "${GREEN}"
echo "=================================================="
echo "    StreamHib V2 - Status Checker"
echo "=================================================="
echo -e "${NC}"

# Cek semua service streamhib
print_status "Mengecek semua service StreamHib..."
services=$(systemctl list-units --type=service --state=loaded | grep streamhib- | awk '{print $1}')

if [ -z "$services" ]; then
    print_warning "Tidak ada service StreamHib yang ditemukan"
    exit 0
fi

echo ""
print_status "Service yang ditemukan:"
echo "$services"

echo ""
print_status "Status detail setiap service:"
echo "=================================================="

for service in $services; do
    echo ""
    echo -e "${BLUE}Service: $service${NC}"
    
    # Cek status
    if systemctl is-active --quiet "$service"; then
        print_success "Status: RUNNING"
    else
        print_error "Status: NOT RUNNING"
    fi
    
    # Ambil port dari service file
    port=$(grep -o 'bind.*:[0-9]*' "/etc/systemd/system/$service" 2>/dev/null | grep -o '[0-9]*$' || echo "Unknown")
    echo "Port: $port"
    
    # Ambil user dari service file
    user=$(grep "^User=" "/etc/systemd/system/$service" 2>/dev/null | cut -d'=' -f2 || echo "Unknown")
    echo "User: $user"
    
    # Cek kuota user jika diketahui
    if [ "$user" != "Unknown" ] && [ "$user" != "root" ]; then
        quota_info=$(quota -u "$user" 2>/dev/null | tail -n +3 | head -1 || echo "No quota info")
        echo "Quota: $quota_info"
    fi
    
    # Test koneksi ke port
    if [ "$port" != "Unknown" ]; then
        if curl -s --connect-timeout 5 "http://localhost:$port" > /dev/null 2>&1; then
            print_success "Port $port: ACCESSIBLE"
        else
            print_warning "Port $port: NOT ACCESSIBLE"
        fi
    fi
    
    echo "----------------------------------------"
done

echo ""
print_status "Ringkasan kuota disk:"
echo "=================================================="
repquota -a 2>/dev/null | grep streamhib_ || print_warning "Tidak ada informasi kuota untuk user streamhib"

echo ""
print_status "Port yang digunakan:"
echo "=================================================="
netstat -tlnp 2>/dev/null | grep -E ':(50[0-9][0-9]|5[1-9][0-9][0-9])' | awk '{print $4, $7}' || print_warning "Netstat tidak tersedia"

echo ""
print_status "Direktori instalasi:"
echo "=================================================="
if [ -d "/opt/streamhib" ]; then
    ls -la /opt/streamhib/
else
    print_warning "Direktori /opt/streamhib tidak ditemukan"
fi

echo ""
print_success "Status check selesai!"