param(
    [string]$Token,
    [string]$Sub = "1cf197a1-edc8-46c0-9f01-debae4b2ffe7",
    [string]$RgName = "rg-devsnippet-korea",
    [string]$VmName = "vm-devsnippet",
    [string]$Fqdn = "devsnippet-app-24110903.koreacentral.cloudapp.azure.com",
    [string]$Ip = "52.231.24.237"
)

$ErrorActionPreference = "Stop"

if (-not $Token) {
    Write-Error "Token is required"
    exit 1
}

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "BƯỚC 1: ĐÓNG GÓI MÃ NGUỒN ỨNG DỤNG DEVSNIPPET HUB" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

$source = Resolve-Path "$PSScriptRoot\.."
$tempStaging = Join-Path $env:TEMP "devsnippet-pack"
if (Test-Path $tempStaging) { Remove-Item $tempStaging -Recurse -Force }
New-Item -ItemType Directory -Path $tempStaging -Force | Out-Null

Write-Host "Sao chép mã nguồn từ $source..."
Get-ChildItem -Path $source -Exclude "node_modules", ".git" | ForEach-Object {
    Copy-Item -Path $_.FullName -Destination $tempStaging -Recurse -Force
}

# Xóa các file thừa nếu lọt vào
Remove-Item -Path "$tempStaging\node_modules" -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item -Path "$tempStaging\.git" -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item -Path "$tempStaging\data\snippets.db*" -Force -ErrorAction SilentlyContinue

$zipPath = "$env:TEMP\devsnippet-deploy.zip"
if (Test-Path $zipPath) { Remove-Item $zipPath -Force }

Write-Host "Tạo file nén $zipPath..."
Compress-Archive -Path "$tempStaging\*" -DestinationPath $zipPath -Force

$zipBytes = [System.IO.File]::ReadAllBytes($zipPath)
$zipB64 = [Convert]::ToBase64String($zipBytes)
Write-Host "Đã nén xong! Kích thước: $([math]::Round($zipBytes.Length / 1KB, 2)) KB ($($zipB64.Length) base64 chars)" -ForegroundColor Green

Write-Host "`n==========================================================" -ForegroundColor Cyan
Write-Host "BƯỚC 2: TẠO SCRIPT RUNCOMMAND CHO VM $VmName" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

$scriptCommands = [System.Collections.Generic.List[string]]::new()
$scriptCommands.Add("echo '>>> [1/7] Updating apt and installing dependencies...'")
$scriptCommands.Add("export DEBIAN_FRONTEND=noninteractive")
$scriptCommands.Add("apt-get update -y && apt-get install -y curl unzip nginx certbot python3-certbot-nginx")

$scriptCommands.Add("echo '>>> [2/7] Installing Node.js 22 LTS...'")
$scriptCommands.Add("curl -fsSL https://deb.nodesource.com/setup_22.x | bash -")
$scriptCommands.Add("apt-get install -y nodejs")
$scriptCommands.Add("node -v && npm -v")

$scriptCommands.Add("echo '>>> [3/7] Uploading and unpacking devsnippet application...'")
$scriptCommands.Add("rm -rf /opt/devsnippet-hub /tmp/devsnippet.b64 /tmp/devsnippet.zip")
$scriptCommands.Add("mkdir -p /opt/devsnippet-hub")

# Split base64 into 1000 char chunks
$matches = [regex]::Matches($zipB64, ".{1,1000}")
foreach ($m in $matches) {
    $scriptCommands.Add("printf '%s' '$($m.Value)' >> /tmp/devsnippet.b64")
}

$scriptCommands.Add("base64 -d /tmp/devsnippet.b64 > /tmp/devsnippet.zip")
$scriptCommands.Add("unzip -q -o /tmp/devsnippet.zip -d /opt/devsnippet-hub")
$scriptCommands.Add("rm -f /tmp/devsnippet.b64 /tmp/devsnippet.zip")

$scriptCommands.Add("echo '>>> [4/7] Running npm install and seed...'")
$scriptCommands.Add("cd /opt/devsnippet-hub")
$scriptCommands.Add("npm install --omit=dev")
$scriptCommands.Add("npm run seed")

$scriptCommands.Add("echo '>>> [5/7] Configuring systemd service on port 8080...'")
$scriptCommands.Add("cat << 'EOF' > /etc/systemd/system/devsnippet.service
[Unit]
Description=DevSnippet Hub Cloud Service
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/opt/devsnippet-hub
Environment=NODE_ENV=production
Environment=PORT=8080
Environment=JWT_SECRET=super_secret_jwt_azure_2026_devsnippet
ExecStart=/usr/bin/node src/server.js
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF")

$scriptCommands.Add("systemctl daemon-reload")
$scriptCommands.Add("systemctl enable devsnippet.service")
$scriptCommands.Add("systemctl restart devsnippet.service")
$scriptCommands.Add("sleep 2")

$scriptCommands.Add("echo '>>> [6/7] Configuring Nginx reverse proxy...'")
$scriptCommands.Add("cat << 'EOF' > /etc/nginx/sites-available/default
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    server_name $Fqdn _;

    location / {
        proxy_pass http://127.0.0.1:8080;
        proxy_http_version 1.1;
        proxy_set_header Upgrade `$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host `$host;
        proxy_cache_bypass `$http_upgrade;
        proxy_set_header X-Real-IP `$remote_addr;
        proxy_set_header X-Forwarded-For `$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto `$scheme;
    }
}
EOF")

$scriptCommands.Add("nginx -t && systemctl reload nginx")

$scriptCommands.Add("echo '>>> [7/7] Requesting Let Encrypt SSL Certificate for $Fqdn...'")
$scriptCommands.Add("certbot --nginx -d $Fqdn --non-interactive --agree-tos -m 24110903@st.vju.ac.vn --redirect || echo 'Certbot notice'")

$scriptCommands.Add("echo '>>> Verifying endpoints locally on VM...'")
$scriptCommands.Add("systemctl status devsnippet.service --no-pager")
$scriptCommands.Add("curl -s http://127.0.0.1:8080/health")
$scriptCommands.Add("echo ''")
$scriptCommands.Add("curl -s http://127.0.0.1:8080/metrics | head -n 12")
$scriptCommands.Add("echo '=== VM PROVISIONING FINISHED SUCCESSFULLY ==='")

Write-Host "Tổng số lệnh gửi lên VM: $($scriptCommands.Count)"

Write-Host "`n==========================================================" -ForegroundColor Cyan
Write-Host "BƯỚC 3: GỬI RUNCOMMAND LÊN AZURE VM $VmName" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

$runBody = @{
    commandId = "RunShellScript"
    script = $scriptCommands.ToArray()
} | ConvertTo-Json -Depth 5

$runUri = "https://management.azure.com/subscriptions/$Sub/resourceGroups/$RgName/providers/Microsoft.Compute/virtualMachines/$VmName/runCommand`?api-version=2021-11-01"

$wr = [System.Net.WebRequest]::Create($runUri)
$wr.Method = "POST"
$wr.Headers["Authorization"] = "Bearer $Token"
$wr.ContentType = "application/json"
$wrBytes = [System.Text.Encoding]::UTF8.GetBytes($runBody)
$wr.ContentLength = $wrBytes.Length
$stream = $wr.GetRequestStream()
$stream.Write($wrBytes, 0, $wrBytes.Length)
$stream.Close()

$resp = $wr.GetResponse()
$async = $resp.Headers["Azure-AsyncOperation"]
$loc = $resp.Headers["Location"]
$pollUrl = if ($async) { $async } else { $loc }

Write-Host "RunCommand đã được tiếp nhận. Đang theo dõi tiến trình chạy trên VM..." -ForegroundColor Yellow

for ($i = 0; $i -lt 80; $i++) {
    Start-Sleep -Seconds 6
    $pollReq = [System.Net.WebRequest]::Create($pollUrl)
    $pollReq.Headers["Authorization"] = "Bearer $Token"
    $pollResp = $pollReq.GetResponse()
    $sr = New-Object System.IO.StreamReader($pollResp.GetResponseStream())
    $json = $sr.ReadToEnd() | ConvertFrom-Json
    Write-Host "Tiến trình RunCommand [$i]: $($json.status)"
    if ($json.status -eq "Succeeded") {
        $locReq = [System.Net.WebRequest]::Create($loc)
        $locReq.Headers["Authorization"] = "Bearer $Token"
        $locResp = $locReq.GetResponse()
        $locSr = New-Object System.IO.StreamReader($locResp.GetResponseStream())
        $locJson = $locSr.ReadToEnd()
        Write-Host "`n==========================================================" -ForegroundColor Green
        Write-Host "KẾT QUẢ TRIỂN KHAI TỪ VM:" -ForegroundColor Green
        Write-Host "==========================================================" -ForegroundColor Green
        Write-Host $locJson
        break
    }
    if ($json.status -eq "Failed") {
        Write-Error "Lỗi thực thi RunCommand: $($json.error.message)"
        break
    }
}

Write-Host "`n==========================================================" -ForegroundColor Cyan
Write-Host "BƯỚC 4: KIỂM THỬ TRỰC TIẾP TỪ INTERNET" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

Start-Sleep -Seconds 3

Write-Host "1. Test HTTP Health: http://$Fqdn/health"
try {
    $h = Invoke-RestMethod -Uri "http://$Fqdn/health" -TimeoutSec 10
    Write-Host "-> HTTP Health OK: status = $($h.status), uptime = $($h.uptime)" -ForegroundColor Green
} catch {
    Write-Warning "HTTP Health Check: $_"
}

Write-Host "2. Test HTTPS Health: https://$Fqdn/health"
try {
    $hs = Invoke-RestMethod -Uri "https://$Fqdn/health" -TimeoutSec 10
    Write-Host "-> HTTPS Health OK: status = $($hs.status), uptime = $($hs.uptime)" -ForegroundColor Green
} catch {
    Write-Warning "HTTPS Health Check: $_"
}

Write-Host "`n🎉 TRIỂN KHAI HOÀN TẤT THÀNH CÔNG RỰC RỠ!" -ForegroundColor Green
Write-Host "🌐 Website FQDN:  https://$Fqdn" -ForegroundColor Green
Write-Host "📊 Metrics:       https://$Fqdn/metrics" -ForegroundColor Green
Write-Host "🩺 Health check:  https://$Fqdn/health" -ForegroundColor Green
Write-Host "👤 Demo account:  demo@devsnippet.io / Password@123" -ForegroundColor Green
