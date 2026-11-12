<#
.SYNOPSIS
    Tự động tìm MONGO_URI trên server Ubuntu qua SSH.

.DESCRIPTION
    Script này SSH vào server và quét các nơi thường chứa connection string:
      1. File .env / config của app backend
      2. docker-compose.yml / Dockerfile
      3. systemd service (Environment=...)
      4. /etc/mongod.conf
      5. Lệnh mongod đang chạy (--dbpath, --port, --auth)

.PARAMETER Host
    IP/domain server. Mặc định: 222.255.184.116

.PARAMETER User
    Tài khoản SSH. Mặc định: root

.PARAMETER KeyPath
    Đường dẫn private key (nếu dùng key thay vì mật khẩu).

.EXAMPLE
    .\get_mongo_uri.ps1 -User root
    .\get_mongo_uri.ps1 -User ubuntu -KeyPath $env:USERPROFILE\.ssh\id_ed25519
#>

param(
    [string]$Server = "222.255.184.116",
    [string]$User   = "root",
    [string]$KeyPath = ""
)

$ErrorActionPreference = "Continue"

# ── Lệnh remote quét tìm URI ───────────────────────────────────────────────
$remoteScript = @'
echo "### 1) Grep trong file cấu hình app"
sudo grep -rInE 'mongodb(\+srv)?://' /opt /srv /var/www /home /root /etc/systemd/system /usr/local 2>/dev/null | head -40

echo
echo "### 2) Docker compose / Dockerfile"
sudo find / -maxdepth 5 \( -name 'docker-compose*.yml' -o -name 'docker-compose*.yaml' -o -name 'compose.yml' \) 2>/dev/null | head -20

echo
echo "### 3) Docker container đang chạy"
sudo docker ps --format '{{.Names}}\t{{.Image}}\t{{.Ports}}' 2>/dev/null | head -20

echo
echo "### 4) Env của container MongoDB"
for c in $(sudo docker ps --format '{{.Names}}' 2>/dev/null | grep -i mongo); do
  echo "--- container: $c ---"
  sudo docker inspect "$c" --format '{{range .Config.Env}}{{println .}}{{end}}' 2>/dev/null | grep -iE 'MONGO|URI'
  sudo docker inspect "$c" --format '{{json .NetworkSettings.Ports}}' 2>/dev/null
done

echo
echo "### 5) systemd service"
sudo systemctl list-units --type=service --all 2>/dev/null | grep -iE 'mongo|api|backend|uvicorn|gunicorn|plant|medical' | head -20
echo "--- Environment= trong service files ---"
sudo grep -rIn 'Environment=' /etc/systemd/system 2>/dev/null | grep -iE 'MONGO|URI' | head -20

echo
echo "### 6) /etc/mongod.conf"
sudo cat /etc/mongod.conf 2>/dev/null | head -40

echo
echo "### 7) Tiến trình mongod đang chạy"
ps aux 2>/dev/null | grep -E '[m]ongod' | head -5

echo
echo "### 8) Port đang LISTEN"
(sudo ss -tlnp 2>/dev/null || sudo netstat -tlnp 2>/dev/null) | grep -E '27017|:80 |:8000|:8080|:3000|:5000' | head -20

echo
echo "### 9) Thư mục app backend"
for d in /opt /srv /var/www /home; do
  sudo ls -la "$d" 2>/dev/null | head -15
done

echo
echo "### 10) File .env tìm được"
sudo find / -maxdepth 6 -name '.env*' -not -path '*/node_modules/*' -not -path '/proc/*' -not -path '/sys/*' 2>/dev/null | head -20
'@

# ── Kết nối SSH ────────────────────────────────────────────────────────────
$sshArgs = @("-o", "StrictHostKeyChecking=accept-new", "-o", "ConnectTimeout=10")

if ($KeyPath -and (Test-Path $KeyPath)) {
    $sshArgs += @("-i", $KeyPath)
}

$target = "$User@$Server"

Write-Host "=== Đang SSH vào $target ===" -ForegroundColor Cyan
Write-Host ""

# Chạy script remote qua stdin (không cần copy file lên server)
$remoteScript | & ssh @sshArgs $target "bash -s" 2>&1 | ForEach-Object { $_ }

Write-Host ""
Write-Host "=== Nếu script trên không tìm thấy, chạy thủ công các lệnh sau ===" -ForegroundColor Yellow
Write-Host @"
ssh $target
# Trên server:
sudo grep -rInE 'mongodb(\+srv)?://' /opt /srv /var/www /home /root 2>/dev/null
sudo systemctl cat <service-name> | grep -i mongo
sudo cat /etc/mongod.conf
sudo docker ps
"@
