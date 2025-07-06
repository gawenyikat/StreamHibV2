# Perbaikan untuk app.py - Multi-user support
# Tambahkan kode ini di bagian awal app.py setelah import

import os
import shutil
import subprocess

# Dapatkan DIRECTORY_BASE dari environment variable atau gunakan default
DIRECTORY_BASE = os.environ.get('STREAMHIB_BASE_DIR', os.path.dirname(os.path.abspath(__file__)))

# Gunakan DIRECTORY_BASE untuk semua file konfigurasi dan data
SESSION_FILE = os.path.join(DIRECTORY_BASE, 'sessions.json')
LOCK_FILE = SESSION_FILE + '.lock'
VIDEO_DIR = os.path.join(DIRECTORY_BASE, "videos")
USERS_FILE = os.path.join(DIRECTORY_BASE, 'users.json')
DOMAIN_CONFIG_FILE = os.path.join(DIRECTORY_BASE, 'domain_config.json')
LOG_DIR = os.path.join(DIRECTORY_BASE, 'logs')

# Pastikan direktori dibuat berdasarkan DIRECTORY_BASE
os.makedirs(os.path.dirname(SESSION_FILE), exist_ok=True)
os.makedirs(VIDEO_DIR, exist_ok=True)
os.makedirs(LOG_DIR, exist_ok=True)

# Konfigurasi logging
import logging
LOG_FILE_PATH = os.path.join(LOG_DIR, 'streamhib_instance.log')
logging.basicConfig(
    level=logging.DEBUG,
    format='%(asctime)s [%(levelname)s] %(message)s',
    handlers=[
        logging.FileHandler(LOG_FILE_PATH),
        logging.StreamHandler()
    ]
)

# Fungsi untuk mendapatkan disk usage dengan quota awareness
def get_disk_usage():
    """
    Mendapatkan informasi penggunaan disk dengan mempertimbangkan quota user
    """
    try:
        # Cek apakah running sebagai user dengan quota
        current_user = os.getenv('USER', 'root')
        
        if current_user.startswith('streamhib_'):
            # Jika running sebagai user streamhib, gunakan quota info
            try:
                result = subprocess.run(['quota', '-u', current_user], 
                                      capture_output=True, text=True, timeout=10)
                if result.returncode == 0:
                    lines = result.stdout.strip().split('\n')
                    if len(lines) >= 3:
                        quota_line = lines[2].split()
                        if len(quota_line) >= 4:
                            used_kb = int(quota_line[1]) if quota_line[1].isdigit() else 0
                            quota_kb = int(quota_line[3]) if quota_line[3].isdigit() else 0
                            
                            if quota_kb > 0:
                                used_bytes = used_kb * 1024
                                total_bytes = quota_kb * 1024
                                free_bytes = total_bytes - used_bytes
                                
                                return {
                                    'total': total_bytes,
                                    'used': used_bytes,
                                    'free': free_bytes,
                                    'quota_enabled': True,
                                    'user': current_user
                                }
            except (subprocess.TimeoutExpired, subprocess.CalledProcessError, ValueError):
                pass
        
        # Fallback ke disk usage normal jika quota tidak tersedia
        statvfs = os.statvfs(DIRECTORY_BASE)
        total_bytes = statvfs.f_frsize * statvfs.f_blocks
        free_bytes = statvfs.f_frsize * statvfs.f_available
        used_bytes = total_bytes - free_bytes
        
        return {
            'total': total_bytes,
            'used': used_bytes,
            'free': free_bytes,
            'quota_enabled': False,
            'user': current_user
        }
        
    except Exception as e:
        logging.error(f"Error getting disk usage: {e}")
        return {
            'total': 0,
            'used': 0,
            'free': 0,
            'quota_enabled': False,
            'user': 'unknown'
        }

# Fungsi helper untuk format bytes
def format_bytes(bytes_value):
    """Convert bytes to human readable format"""
    for unit in ['B', 'KB', 'MB', 'GB', 'TB']:
        if bytes_value < 1024.0:
            return f"{bytes_value:.1f} {unit}"
        bytes_value /= 1024.0
    return f"{bytes_value:.1f} PB"

# Tambahkan ke context processor untuk template
@app.context_processor
def inject_disk_usage():
    disk_info = get_disk_usage()
    return {
        'disk_usage': {
            'total': format_bytes(disk_info['total']),
            'used': format_bytes(disk_info['used']),
            'free': format_bytes(disk_info['free']),
            'used_percent': round((disk_info['used'] / disk_info['total']) * 100, 1) if disk_info['total'] > 0 else 0,
            'quota_enabled': disk_info['quota_enabled'],
            'user': disk_info['user']
        }
    }

# Fungsi untuk cek apakah user mendekati quota limit
def check_quota_warning():
    """
    Cek apakah user mendekati batas quota (>80%)
    """
    disk_info = get_disk_usage()
    if disk_info['total'] > 0:
        usage_percent = (disk_info['used'] / disk_info['total']) * 100
        if usage_percent > 80:
            return {
                'warning': True,
                'usage_percent': round(usage_percent, 1),
                'message': f"Storage usage is {usage_percent:.1f}% of quota limit"
            }
    return {'warning': False}

# API endpoint untuk mendapatkan disk usage
@app.route('/api/disk-usage')
def api_disk_usage():
    """API endpoint untuk mendapatkan informasi disk usage"""
    if not is_logged_in():
        return jsonify({'success': False, 'message': 'Not authenticated'}), 401
    
    disk_info = get_disk_usage()
    quota_warning = check_quota_warning()
    
    return jsonify({
        'success': True,
        'disk_usage': {
            'total_bytes': disk_info['total'],
            'used_bytes': disk_info['used'],
            'free_bytes': disk_info['free'],
            'total': format_bytes(disk_info['total']),
            'used': format_bytes(disk_info['used']),
            'free': format_bytes(disk_info['free']),
            'used_percent': round((disk_info['used'] / disk_info['total']) * 100, 1) if disk_info['total'] > 0 else 0,
            'quota_enabled': disk_info['quota_enabled'],
            'user': disk_info['user']
        },
        'quota_warning': quota_warning
    })

# Modifikasi fungsi upload untuk cek quota sebelum upload
def check_quota_before_upload(file_size):
    """
    Cek apakah ada cukup space sebelum upload
    """
    disk_info = get_disk_usage()
    if disk_info['quota_enabled'] and disk_info['free'] < file_size:
        return False, f"Not enough quota space. Available: {format_bytes(disk_info['free'])}, Required: {format_bytes(file_size)}"
    return True, "OK"

# Tambahkan logging untuk debugging
logging.info(f"StreamHib V2 Multi-User initialized")
logging.info(f"Base directory: {DIRECTORY_BASE}")
logging.info(f"Video directory: {VIDEO_DIR}")
logging.info(f"Current user: {os.getenv('USER', 'unknown')}")

disk_info = get_disk_usage()
logging.info(f"Disk usage - Total: {format_bytes(disk_info['total'])}, Used: {format_bytes(disk_info['used'])}, Quota enabled: {disk_info['quota_enabled']}")