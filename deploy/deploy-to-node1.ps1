# ==============================================================================
# SCRIPT DEPLOY TRỰC TIẾP LÊN MÁY ẢO UBUNTU NODE1 TRÊN AZURE
# ==============================================================================

param(
    [string]$token = $env:AZURE_ACCESS_TOKEN
)
$sub = "1cf197a1-edc8-46c0-9f01-debae4b2ffe7"
$source = "c:\Users\24110\OneDrive\Desktop\GKLTNC\devsnippet-hub"

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "ĐANG ĐÓNG GÓI ỨNG DỤNG DEVSNIPPET HUB..." -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

$zipPath = "$env:TEMP\devsnippet-deploy.zip"
if (Test-Path $zipPath) { Remove-Item $zipPath -Force }

$files = Get-ChildItem -Path $source -Recurse -File | Where-Object { 
    $_.FullName -notmatch '\\node_modules\\' -and 
    $_.FullName -notmatch '\\\.git\\' -and 
    $_.FullName -notmatch '\\data\\' 
}

$stageDir = "$env:TEMP\devsnippet-stage"
if (Test-Path $stageDir) { Remove-Item $stageDir -Recurse -Force }
New-Item -ItemType Directory -Path $stageDir | Out-Null

foreach ($f in $files) {
    $rel = $f.FullName.Substring($source.Length + 1)
    $dest = Join-Path $stageDir $rel
    $destDir = Split-Path $dest -Parent
    if (-not (Test-Path $destDir)) { New-Item -ItemType Directory -Path $destDir -Force | Out-Null }
    Copy-Item $f.FullName $dest -Force
}

Compress-Archive -Path "$stageDir\*" -DestinationPath $zipPath -Force
$bytes = [System.IO.File]::ReadAllBytes($zipPath)
$b64 = [Convert]::ToBase64String($bytes)

Write-Host "Gói ZIP hoàn tất: $($bytes.Length) bytes (Base64: $($b64.Length) chars)" -ForegroundColor Green

# Viết file script bash chạy trên Ubuntu VM
$remoteScript = @"
#!/bin/bash
set -e

echo '>>> [1/6] Installing unzip & prerequisites...'
export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get install -y unzip curl

echo '>>> [2/6] Installing Node.js 22 LTS if needed...'
if ! command -v node &> /dev/null; then
    curl -fsSL https://deb.nodesource.com/setup_22.x | bash -
    apt-get install -y nodejs
fi
node -v
npm -v

echo '>>> [3/6] Deploying DevSnippet Hub files...'
mkdir -p /opt/devsnippet-hub
cat << 'EOF' > /tmp/devsnippet_b64.txt
$b64
EOF
base64 -d /tmp/devsnippet_b64.txt > /tmp/devsnippet.zip
unzip -o /tmp/devsnippet.zip -d /opt/devsnippet-hub
rm -f /tmp/devsnippet_b64.txt /tmp/devsnippet.zip

echo '>>> [4/6] Installing dependencies and seeding database...'
cd /opt/devsnippet-hub
npm install --omit=dev
npm run seed

echo '>>> [5/6] Configuring systemd service on port 80...'
cat << 'EOF' > /etc/systemd/system/devsnippet.service
[Unit]
Description=DevSnippet Hub Cloud Service
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/opt/devsnippet-hub
Environment=NODE_ENV=production
Environment=PORT=80
Environment=JWT_SECRET=super_secret_jwt_azure_2026_devsnippet
ExecStart=/usr/bin/node src/server.js
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable devsnippet.service
systemctl restart devsnippet.service

# Mở firewall nội bộ nếu UFW đang bật
if command -v ufw &> /dev/null; then
    ufw allow 80/tcp || true
fi

echo '>>> [6/6] Verifying service health...'
sleep 3
systemctl status devsnippet.service --no-pager
curl -i http://localhost/health

echo '>>> DEPLOYMENT COMPLETED SUCCESSFULLY!'
"@

Write-Host "`nĐang gửi lệnh triển khai đến máy ảo node1 qua Azure RunCommand API..." -ForegroundColor Yellow

$body = @{
    commandId = "RunShellScript"
    script = @($remoteScript)
} | ConvertTo-Json

$uri = "https://management.azure.com/subscriptions/$sub/resourceGroups/DTDM/providers/Microsoft.Compute/virtualMachines/node1/runCommand?api-version=2021-11-01"

$wr = [System.Net.WebRequest]::Create($uri)
$wr.Method = "POST"
$wr.Headers["Authorization"] = "Bearer $token"
$wr.ContentType = "application/json"
$wrBytes = [System.Text.Encoding]::UTF8.GetBytes($body)
$wr.ContentLength = $wrBytes.Length
$stream = $wr.GetRequestStream()
$stream.Write($wrBytes, 0, $wrBytes.Length)
$stream.Close()

$resp = $wr.GetResponse()
$async = $resp.Headers["Azure-AsyncOperation"]
$loc = $resp.Headers["Location"]
$pollUrl = if ($async) { $async } else { $loc }

Write-Host "Lệnh đã được Azure chấp nhận (202 Accepted). Đang theo dõi tiến trình chạy trên VM..." -ForegroundColor Yellow

for ($i = 0; $i -lt 40; $i++) {
    Start-Sleep -Seconds 5
    $pollReq = [System.Net.WebRequest]::Create($pollUrl)
    $pollReq.Headers["Authorization"] = "Bearer $token"
    $pollResp = $pollReq.GetResponse()
    $sr = New-Object System.IO.StreamReader($pollResp.GetResponseStream())
    $json = $sr.ReadToEnd() | ConvertFrom-Json
    
    Write-Host "Tiến độ [$i]: $($json.status)"
    if ($json.status -eq "Succeeded") {
        Write-Host "`n==========================================================" -ForegroundColor Green
        Write-Host "TRIỂN KHAI THÀNH CÔNG LÊN MÁY ẢO NODE1!" -ForegroundColor Green
        Write-Host "🌐 Địa chỉ trang Web: http://20.205.99.237" -ForegroundColor Green
        Write-Host "🩺 Health Check:    http://20.205.99.237/health" -ForegroundColor Green
        Write-Host "📊 Metrics Monitor:  http://20.205.99.237/metrics" -ForegroundColor Green
        Write-Host "==========================================================" -ForegroundColor Green
        break
    }
    if ($json.status -eq "Failed") {
        Write-Error "Triển khai thất bại: $($json.error.message)"
        break
    }
}
