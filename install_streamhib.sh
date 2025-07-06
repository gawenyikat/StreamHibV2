#!/bin/bash

# === INPUT ===
USERNAME=$1
PORT=$2

if [ -z "$USERNAME" ] || [ -z "$PORT" ]; then
  echo "Usage: $0 <username_instans> <port>"
  exit 1
fi

APP_DIR="/root/StreamHibV2-$USERNAME"
SERVICE_FILE="/etc/systemd/system/streamhibv2-$USERNAME.service"
USER_SYS="streamhib_$USERNAME"

# === 1. Buat direktori aplikasi ===
mkdir -p "$APP_DIR"
cd "$APP_DIR"

# === 2. Clone kode aplikasi ===
git clone https://github.com/gawenyikat/StreamHibV2.git temp_source
mv temp_source/* .
rm -rf temp_source

# === 3. Buat virtual environment ===
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt

# === 4. Setup user sistem khusus ===
if ! id -u "$USER_SYS" >/dev/null 2>&1; then
  adduser --system --no-create-home "$USER_SYS"
fi

# === 5. Set permission direktori ===
chown -R "$USER_SYS":"$USER_SYS" "$APP_DIR"

# === 6. Buat systemd service ===
cat > "$SERVICE_FILE" <<EOF
[Unit]
Description=StreamHib Flask Service for $USERNAME (Port $PORT)
After=network.target

[Service]
User=$USER_SYS
Group=$USER_SYS
WorkingDirectory=$APP_DIR
ExecStart=$APP_DIR/venv/bin/gunicorn -k eventlet -w 1 -b 0.0.0.0:$PORT app:app
Restart=always

[Install]
WantedBy=multi-user.target
EOF

# === 7. Reload systemd dan enable service ===
systemctl daemon-reexec
systemctl daemon-reload
systemctl enable streamhibv2-$USERNAME.service
systemctl start streamhibv2-$USERNAME.service

# === 8. Buka firewall port ===
ufw allow $PORT/tcp

# === 9. Tambah kuota disk (jika belum aktif) ===
FSTAB_LINE=$(grep -E "\s/\s" /etc/fstab)
if [[ "$FSTAB_LINE" != *usrjquota* ]]; then
  echo "[!] Mengaktifkan quota di /etc/fstab..."
  cp /etc/fstab /etc/fstab.bak
  sed -i.bak '/\s\/\s/s/defaults/defaults,usrjquota=aquota.user,grpjquota=aquota.group,jqfmt=vfsv0/' /etc/fstab
  mount -o remount /
  quotacheck -cum /
  quotaon -ug /
fi

# === 10. Atur kuota default 30GB/35GB untuk user instans ===
SOFT=31457280  # 30GB in KB
HARD=36700160  # 35GB in KB
DEVICE=$(df / | tail -1 | awk '{print $1}')
echo "$USER_SYS $DEVICE $SOFT $HARD 0 0" | awk '{printf "edquota -u %s <<EOF\n%s %s %s %s %s %s\nEOF\n", $1, $2, $3, $4, $5, $5, $6}' | bash

# === DONE ===
echo -e "\nInstans $USERNAME berhasil dibuat di port $PORT."
echo "Direktori: $APP_DIR"
echo "User sistem: $USER_SYS"
echo "Service: streamhibv2-$USERNAME.service"
echo "Quota: Soft ${SOFT}KB, Hard ${HARD}KB untuk $USER_SYS di $DEVICE"
