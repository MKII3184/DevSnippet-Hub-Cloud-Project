param(
    [string]$token = $env:AZURE_ACCESS_TOKEN
)
$sub = "1cf197a1-edc8-46c0-9f01-debae4b2ffe7"
$domain = "devsnippet-24110903.eastasia.cloudapp.azure.com"

$bash = @"
#!/bin/bash
set -e

echo '>>> 1. Switching Node.js app to port 8080...'
sed -i 's/Environment=PORT=80/Environment=PORT=8080/' /etc/systemd/system/devsnippet.service
systemctl daemon-reload
systemctl restart devsnippet.service

echo '>>> 2. Installing Nginx and Certbot...'
export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get install -y nginx certbot python3-certbot-nginx

echo '>>> 3. Configuring Nginx reverse proxy...'
cat << 'EOF' > /etc/nginx/sites-available/devsnippet
server {
    listen 80;
    server_name $domain;

    location / {
        proxy_pass http://127.0.0.1:8080;
        proxy_http_version 1.1;
        proxy_set_header Upgrade `$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host `$host;
        proxy_set_header X-Real-IP `$remote_addr;
        proxy_set_header X-Forwarded-For `$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto `$scheme;
        proxy_cache_bypass `$http_upgrade;
    }
}
EOF

ln -sf /etc/nginx/sites-available/devsnippet /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default
nginx -t
systemctl restart nginx

echo '>>> 4. Obtaining Let Encrypt SSL Certificate for HTTPS...'
certbot --nginx -d $domain --non-interactive --agree-tos --email 24110903@st.vju.ac.vn --redirect || true

echo '>>> 5. Testing HTTPS & HTTP...'
systemctl status nginx --no-pager
curl -k -i https://localhost/health
"@

$commands = $bash -split "`r?`n"

$body = @{
    commandId = "RunShellScript"
    script = $commands
} | ConvertTo-Json -Depth 5

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

Write-Host "HTTPS Setup submitted. Polling..."
for ($i = 0; $i -lt 30; $i++) {
    Start-Sleep -Seconds 5
    $pollReq = [System.Net.WebRequest]::Create($pollUrl)
    $pollReq.Headers["Authorization"] = "Bearer $token"
    $pollResp = $pollReq.GetResponse()
    $sr = New-Object System.IO.StreamReader($pollResp.GetResponseStream())
    $json = $sr.ReadToEnd() | ConvertFrom-Json
    Write-Host "Status [$i]: $($json.status)"
    if ($json.status -eq "Succeeded") {
        Write-Host "HTTPS Setup Succeeded!"
        break
    }
    if ($json.status -eq "Failed") {
        Write-Error "Failed: $($json.error.message)"
        break
    }
}
