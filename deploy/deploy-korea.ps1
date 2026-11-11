# ==============================================================================
# SCRIPT TRIỂN KHAI TOÀN DIỆN DEVSNIPPET HUB TRÊN AZURE (KOREA CENTRAL)
# ==============================================================================
param(
    [string]$Token,
    [string]$Sub = "1cf197a1-edc8-46c0-9f01-debae4b2ffe7",
    [string]$RgName = "rg-devsnippet-korea",
    [string]$Location = "koreacentral",
    [string]$VmName = "vm-devsnippet",
    [string]$DnsLabel = "devsnippet-app-24110903"
)

$ErrorActionPreference = "Stop"

if (-not $Token) {
    Write-Error "Vui lòng cung cấp Access Token!"
    exit 1
}

$headers = @{
    "Authorization" = "Bearer $Token"
    "Content-Type"  = "application/json"
}

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "BƯỚC 1: TẠO RESOURCE GROUP $RgName TẠI $Location" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

$rgUri = "https://management.azure.com/subscriptions/$Sub/resourcegroups/$RgName`?api-version=2021-04-01"
$rgBody = @{
    location = $Location
    tags = @{
        Project = "CloudComputing"
        App = "DevSnippet-Hub"
        StudentId = "24110903"
    }
} | ConvertTo-Json

try {
    $rgRes = Invoke-RestMethod -Method Put -Uri $rgUri -Headers $headers -Body $rgBody
    Write-Host "Resource Group '$RgName' tại $Location đã sẵn sàng! State: $($rgRes.properties.provisioningState)" -ForegroundColor Green
} catch {
    Write-Error "Lỗi tạo Resource Group: $_"
    exit 1
}

Write-Host "`n==========================================================" -ForegroundColor Cyan
Write-Host "BƯỚC 2: TRIỂN KHAI HẠ TẦNG ARM TEMPLATE (VNet, Subnet, NSG, PIP, NIC, VM)" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

$armTemplate = @{
    "`$schema" = "https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#"
    contentVersion = "1.0.0.0"
    parameters = @{}
    variables = @{
        vnetName = "vnet-devsnippet"
        subnetName = "snet-default"
        nsgName = "nsg-devsnippet"
        pipName = "pip-devsnippet"
        nicName = "nic-devsnippet"
        vmName = $VmName
        adminUsername = "azureuser"
        adminPassword = "DevSnippet@Secure2026!"
    }
    resources = @(
        # Public IP
        @{
            type = "Microsoft.Network/publicIPAddresses"
            apiVersion = "2021-05-01"
            name = "[variables('pipName')]"
            location = $Location
            sku = @{ name = "Standard" }
            properties = @{
                publicIPAllocationMethod = "Static"
                dnsSettings = @{
                    domainNameLabel = $DnsLabel
                }
            }
        },
        # NSG
        @{
            type = "Microsoft.Network/networkSecurityGroups"
            apiVersion = "2021-05-01"
            name = "[variables('nsgName')]"
            location = $Location
            properties = @{
                securityRules = @(
                    @{
                        name = "Allow-HTTP"
                        properties = @{
                            priority = 100
                            direction = "Inbound"
                            access = "Allow"
                            protocol = "Tcp"
                            sourcePortRange = "*"
                            destinationPortRange = "80"
                            sourceAddressPrefix = "*"
                            destinationAddressPrefix = "*"
                        }
                    },
                    @{
                        name = "Allow-HTTPS"
                        properties = @{
                            priority = 110
                            direction = "Inbound"
                            access = "Allow"
                            protocol = "Tcp"
                            sourcePortRange = "*"
                            destinationPortRange = "443"
                            sourceAddressPrefix = "*"
                            destinationAddressPrefix = "*"
                        }
                    },
                    @{
                        name = "Allow-SSH"
                        properties = @{
                            priority = 120
                            direction = "Inbound"
                            access = "Allow"
                            protocol = "Tcp"
                            sourcePortRange = "*"
                            destinationPortRange = "22"
                            sourceAddressPrefix = "*"
                            destinationAddressPrefix = "*"
                        }
                    }
                )
            }
        },
        # VNet
        @{
            type = "Microsoft.Network/virtualNetworks"
            apiVersion = "2021-05-01"
            name = "[variables('vnetName')]"
            location = $Location
            properties = @{
                addressSpace = @{
                    addressPrefixes = @("10.30.0.0/16")
                }
                subnets = @(
                    @{
                        name = "[variables('subnetName')]"
                        properties = @{
                            addressPrefix = "10.30.1.0/24"
                        }
                    }
                )
            }
        },
        # NIC
        @{
            type = "Microsoft.Network/networkInterfaces"
            apiVersion = "2021-05-01"
            name = "[variables('nicName')]"
            location = $Location
            dependsOn = @(
                "[resourceId('Microsoft.Network/virtualNetworks', variables('vnetName'))]",
                "[resourceId('Microsoft.Network/publicIPAddresses', variables('pipName'))]",
                "[resourceId('Microsoft.Network/networkSecurityGroups', variables('nsgName'))]"
            )
            properties = @{
                ipConfigurations = @(
                    @{
                        name = "ipconfig1"
                        properties = @{
                            privateIPAllocationMethod = "Dynamic"
                            subnet = @{
                                id = "[resourceId('Microsoft.Network/virtualNetworks/subnets', variables('vnetName'), variables('subnetName'))]"
                            }
                            publicIPAddress = @{
                                id = "[resourceId('Microsoft.Network/publicIPAddresses', variables('pipName'))]"
                            }
                        }
                    }
                )
                networkSecurityGroup = @{
                    id = "[resourceId('Microsoft.Network/networkSecurityGroups', variables('nsgName'))]"
                }
            }
        },
        # VM (Standard_B2s_v2, Ubuntu 24.04 LTS)
        @{
            type = "Microsoft.Compute/virtualMachines"
            apiVersion = "2021-11-01"
            name = "[variables('vmName')]"
            location = $Location
            dependsOn = @(
                "[resourceId('Microsoft.Network/networkInterfaces', variables('nicName'))]"
            )
            properties = @{
                hardwareProfile = @{
                    vmSize = "Standard_B2s_v2"
                }
                storageProfile = @{
                    imageReference = @{
                        publisher = "Canonical"
                        offer = "ubuntu-24_04-lts"
                        sku = "server"
                        version = "latest"
                    }
                    osDisk = @{
                        createOption = "FromImage"
                        caching = "ReadWrite"
                        managedDisk = @{
                            storageAccountType = "Standard_LRS"
                        }
                    }
                }
                osProfile = @{
                    computerName = "[variables('vmName')]"
                    adminUsername = "[variables('adminUsername')]"
                    adminPassword = "[variables('adminPassword')]"
                    linuxConfiguration = @{
                        disablePasswordAuthentication = $false
                    }
                }
                networkProfile = @{
                    networkInterfaces = @(
                        @{
                            id = "[resourceId('Microsoft.Network/networkInterfaces', variables('nicName'))]"
                        }
                    )
                }
            }
        }
    )
}

$deploymentName = "deploy-korea-" + (Get-Random -Minimum 1000 -Maximum 9999)
$deployBody = @{
    properties = @{
        mode = "Incremental"
        template = $armTemplate
    }
} | ConvertTo-Json -Depth 15

Write-Host "Đang gửi ARM Template tạo VM Standard_B2s tại $Location..." -ForegroundColor Yellow
$deployUri = "https://management.azure.com/subscriptions/$Sub/resourcegroups/$RgName/providers/Microsoft.Resources/deployments/$deploymentName`?api-version=2021-04-01"

try {
    $wr = [System.Net.WebRequest]::Create($deployUri)
    $wr.Method = "PUT"
    $wr.Headers["Authorization"] = "Bearer $Token"
    $wr.ContentType = "application/json"
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($deployBody)
    $wr.ContentLength = $bytes.Length
    $s = $wr.GetRequestStream()
    $s.Write($bytes, 0, $bytes.Length)
    $s.Close()
    $resp = $wr.GetResponse()
} catch [System.Net.WebException] {
    $errStream = $_.Exception.Response.GetResponseStream()
    $reader = New-Object System.IO.StreamReader($errStream)
    $errText = $reader.ReadToEnd()
    Write-Host "LỖI CHI TIẾT TỪ AZURE ARM:" -ForegroundColor Red
    Write-Host $errText -ForegroundColor Red
    throw $_
}
$asyncUrl = $resp.Headers["Azure-AsyncOperation"]
if (-not $asyncUrl) { $asyncUrl = $resp.Headers["Location"] }

Write-Host "ARM Deployment đã submit. Đang chờ hạ tầng hoàn tất khởi tạo..." -ForegroundColor Yellow

for ($i = 0; $i -lt 50; $i++) {
    Start-Sleep -Seconds 6
    $pollReq = [System.Net.WebRequest]::Create($asyncUrl)
    $pollReq.Headers["Authorization"] = "Bearer $Token"
    $pollResp = $pollReq.GetResponse()
    $sr = New-Object System.IO.StreamReader($pollResp.GetResponseStream())
    $json = $sr.ReadToEnd() | ConvertFrom-Json
    Write-Host "Tiến trình ARM [$i]: $($json.status)"
    if ($json.status -eq "Succeeded") {
        Write-Host "`n✅ MÁY ẢO MỚI $VmName VÀ HẠ TẦNG ĐÃ ĐƯỢC TẠO THÀNH CÔNG!" -ForegroundColor Green
        break
    }
    if ($json.status -eq "Failed") {
        throw "Tạo máy ảo thất bại: $($json.error.message)"
    }
}

# Lấy Public IP và FQDN
$pipUri = "https://management.azure.com/subscriptions/$Sub/resourceGroups/$RgName/providers/Microsoft.Network/publicIPAddresses/pip-devsnippet`?api-version=2021-05-01"
$pipRes = Invoke-RestMethod -Uri $pipUri -Headers $headers
$finalFqdn = $pipRes.properties.dnsSettings.fqdn
$finalIp = $pipRes.properties.ipAddress

Write-Host "`n==========================================================" -ForegroundColor Green
Write-Host "🌐 Tên miền FQDN mới: $finalFqdn" -ForegroundColor Green
Write-Host "📍 IP công khai mới:   $finalIp" -ForegroundColor Green
Write-Host "==========================================================" -ForegroundColor Green

Write-Host "`n==========================================================" -ForegroundColor Cyan
Write-Host "BƯỚC 3: ĐÓNG GÓI ỨNG DỤNG VÀ CHUẨN BỊ NẠP VÀO MÁY ẢO" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

$zipPath = "$env:TEMP\devsnippet-deploy.zip"
if (Test-Path $zipPath) { Remove-Item $zipPath -Force }

$source = Resolve-Path "$PSScriptRoot\.."
Write-Host "Nén thư mục $source vào $zipPath (bỏ qua node_modules, data, .git)..."

Add-Type -AssemblyName System.IO.Compression.FileSystem
$compressionLevel = [System.IO.Compression.CompressionLevel]::Optimal
$zipArchive = [System.IO.Compression.ZipFile]::Open($zipPath, [System.IO.Compression.ZipArchiveMode]::Create)

$allFiles = Get-ChildItem -Path $source -Recurse -File | Where-Object {
    $_.FullName -notmatch '\\node_modules(\\|$)' -and
    $_.FullName -notmatch '\\\.git(\\|$)' -and
    $_.FullName -notmatch '\\data\\snippets\.db'
}

foreach ($file in $allFiles) {
    $rel = $file.FullName.Substring($source.Path.Length + 1)
    [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zipArchive, $file.FullName, $rel, $compressionLevel)
}
$zipArchive.Dispose()

$zipBytes = [System.IO.File]::ReadAllBytes($zipPath)
$zipB64 = [Convert]::ToBase64String($zipBytes)
Write-Host "Kích thước gói nén: $([math]::Round($zipBytes.Length / 1KB, 2)) KB" -ForegroundColor Green

Write-Host "`n==========================================================" -ForegroundColor Cyan
Write-Host "BƯỚC 4: THỰC THI AZURE RUN COMMAND ĐỂ CÀI ĐẶT NODE.JS, NGINX, SSL VÀ CHẠY APP" -ForegroundColor Cyan
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

$scriptCommands.Add("echo '>>> [5/7] Configuring systemd service for DevSnippet Hub on port 8080...'")
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
    server_name $finalFqdn _;

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

$scriptCommands.Add("echo '>>> [7/7] Requesting Let Encrypt SSL Certificate for $finalFqdn...'")
$scriptCommands.Add("certbot --nginx -d $finalFqdn --non-interactive --agree-tos -m 24110903@st.vju.ac.vn --redirect || echo 'Certbot completed or skipped'")

$scriptCommands.Add("echo '>>> Verifying local endpoints...'")
$scriptCommands.Add("curl -s http://127.0.0.1:8080/health")
$scriptCommands.Add("echo ''")
$scriptCommands.Add("curl -s http://127.0.0.1:8080/metrics | head -n 10")
$scriptCommands.Add("echo 'SETUP COMPLETE'")

$runBody = @{
    commandId = "RunShellScript"
    script = $scriptCommands.ToArray()
} | ConvertTo-Json -Depth 5

$runUri = "https://management.azure.com/subscriptions/$Sub/resourceGroups/$RgName/providers/Microsoft.Compute/virtualMachines/$VmName/runCommand`?api-version=2021-11-01"

Write-Host "Đang gửi kịch bản RunCommand cài đặt lên máy ảo $VmName..." -ForegroundColor Yellow
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

Write-Host "Lệnh RunCommand đã được tiếp nhận. Đang theo dõi tiến trình chạy trên VM..." -ForegroundColor Yellow
for ($i = 0; $i -lt 60; $i++) {
    Start-Sleep -Seconds 6
    $pollReq = [System.Net.WebRequest]::Create($pollUrl)
    $pollReq.Headers["Authorization"] = "Bearer $Token"
    $pollResp = $pollReq.GetResponse()
    $sr = New-Object System.IO.StreamReader($pollResp.GetResponseStream())
    $json = $sr.ReadToEnd() | ConvertFrom-Json
    Write-Host "Trạng thái RunCommand [$i]: $($json.status)"
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
Write-Host "BƯỚC 5: KIỂM THỬ TRỰC TIẾP TỪ INTERNET" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

Start-Sleep -Seconds 3

Write-Host "1. Test HTTP Health: http://$finalFqdn/health"
try {
    $h = Invoke-RestMethod -Uri "http://$finalFqdn/health" -TimeoutSec 10
    Write-Host "-> HTTP Health OK: status = $($h.status), uptime = $($h.uptime)" -ForegroundColor Green
} catch {
    Write-Warning "HTTP Health Check: $_"
}

Write-Host "2. Test HTTPS Health: https://$finalFqdn/health"
try {
    $hs = Invoke-RestMethod -Uri "https://$finalFqdn/health" -TimeoutSec 10
    Write-Host "-> HTTPS Health OK: status = $($hs.status), uptime = $($hs.uptime)" -ForegroundColor Green
} catch {
    Write-Warning "HTTPS Health Check: $_"
}

Write-Host "`n🎉 TRIỂN KHAI HOÀN TẤT THÀNH CÔNG RỰC RỠ!" -ForegroundColor Green
Write-Host "🌐 Website FQDN:  https://$finalFqdn" -ForegroundColor Green
Write-Host "📊 Metrics:       https://$finalFqdn/metrics" -ForegroundColor Green
Write-Host "🩺 Health check:  https://$finalFqdn/health" -ForegroundColor Green
Write-Host "👤 Demo account:  demo@devsnippet.io / Password@123" -ForegroundColor Green
