param(
    [string]$token = $env:AZURE_ACCESS_TOKEN
)
$sub = "1cf197a1-edc8-46c0-9f01-debae4b2ffe7"
$source = "c:\Users\24110\OneDrive\Desktop\GKLTNC\devsnippet-hub"

# 1. Zip
$zipPath = "$env:TEMP\devsnippet-deploy.zip"
$bytes = [System.IO.File]::ReadAllBytes($zipPath)
$b64 = [Convert]::ToBase64String($bytes)

# 2. Build bash lines
$scriptCommands = [System.Collections.Generic.List[string]]::new()
$scriptCommands.Add("echo '>>> Step 1: Cleaning and preparing /tmp/devsnippet.b64...'")
$scriptCommands.Add("rm -rf /opt/devsnippet-hub /tmp/devsnippet.b64 /tmp/devsnippet.zip")
$scriptCommands.Add("mkdir -p /opt/devsnippet-hub")

# Split base64 into 1000 char chunks
$matches = [regex]::Matches($b64, ".{1,1000}")
foreach ($m in $matches) {
    $scriptCommands.Add("printf '%s' '$($m.Value)' >> /tmp/devsnippet.b64")
}

$scriptCommands.Add("echo '>>> Step 2: Unpacking files...'")
$scriptCommands.Add("base64 -d /tmp/devsnippet.b64 > /tmp/devsnippet.zip")
$scriptCommands.Add("unzip -q -o /tmp/devsnippet.zip -d /opt/devsnippet-hub")
$scriptCommands.Add("rm -f /tmp/devsnippet.b64 /tmp/devsnippet.zip")

$scriptCommands.Add("echo '>>> Step 3: npm install and seed...'")
$scriptCommands.Add("cd /opt/devsnippet-hub")
$scriptCommands.Add("npm install --omit=dev")
$scriptCommands.Add("npm run seed")

$scriptCommands.Add("echo '>>> Step 4: Configuring systemd service on port 80...'")
$scriptCommands.Add("cat << 'EOF' > /etc/systemd/system/devsnippet.service
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
EOF")

$scriptCommands.Add("systemctl daemon-reload")
$scriptCommands.Add("systemctl enable devsnippet.service")
$scriptCommands.Add("systemctl restart devsnippet.service")
$scriptCommands.Add("sleep 2")
$scriptCommands.Add("systemctl status devsnippet.service --no-pager")
$scriptCommands.Add("curl -i http://localhost/health")

Write-Host "Total bash command lines to send:" $scriptCommands.Count

# 3. Send RunCommand
$body = @{
    commandId = "RunShellScript"
    script = $scriptCommands.ToArray()
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

Write-Host "Lệnh đã được gửi đi. Đang chờ kết quả thực thi..."
for ($i = 0; $i -lt 30; $i++) {
    Start-Sleep -Seconds 4
    $pollReq = [System.Net.WebRequest]::Create($pollUrl)
    $pollReq.Headers["Authorization"] = "Bearer $token"
    $pollResp = $pollReq.GetResponse()
    $sr = New-Object System.IO.StreamReader($pollResp.GetResponseStream())
    $json = $sr.ReadToEnd() | ConvertFrom-Json
    Write-Host "Trạng thái [$i]: $($json.status)"
    if ($json.status -eq "Succeeded") {
        $locReq = [System.Net.WebRequest]::Create($loc)
        $locReq.Headers["Authorization"] = "Bearer $token"
        $locResp = $locReq.GetResponse()
        $locSr = New-Object System.IO.StreamReader($locResp.GetResponseStream())
        $locJson = $locSr.ReadToEnd()
        Write-Host "KẾT QUẢ TỪ VM:"
        Write-Host $locJson
        break
    }
    if ($json.status -eq "Failed") {
        Write-Error "Lỗi thực thi: $($json.error.message)"
        break
    }
}
