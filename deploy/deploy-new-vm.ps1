# ==============================================================================
# SCRIPT TẠO MÁY ẢO MỚI HOÀN TOÀN TRÊN AZURE (SOUTHEAST ASIA)
# ==============================================================================
param(
    [string]$Token,
    [string]$Sub = "1cf197a1-edc8-46c0-9f01-debae4b2ffe7",
    [string]$RgName = "rg-devsnippet-sea",
    [string]$Location = "southeastasia",
    [string]$VmName = "vm-devsnippet",
    [string]$DnsLabel = "devsnippet-app-24110903"
)

$ErrorActionPreference = "Stop"
$headers = @{ "Authorization" = "Bearer $Token"; "Content-Type" = "application/json" }

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "BẮT ĐẦU TẠO MÁY ẢO MỚI TRÊN RESOURCE GROUP: $RgName ($Location)" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

# 1. ARM Template định nghĩa toàn bộ hạ tầng mới
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
                    addressPrefixes = @("10.20.0.0/16")
                }
                subnets = @(
                    @{
                        name = "[variables('subnetName')]"
                        properties = @{
                            addressPrefix = "10.20.1.0/24"
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
        # VM
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
                    vmSize = "Standard_B2s"
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

$deploymentName = "deploy-newvm-" + (Get-Random -Minimum 1000 -Maximum 9999)
$deployBody = @{
    properties = @{
        mode = "Incremental"
        template = $armTemplate
    }
} | ConvertTo-Json -Depth 15

Write-Host "Đang gửi ARM Template triển khai hạ tầng lên Azure ($Location)..." -ForegroundColor Yellow
$deployUri = "https://management.azure.com/subscriptions/$Sub/resourcegroups/$RgName/providers/Microsoft.Resources/deployments/$deploymentName`?api-version=2021-04-01"

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
$asyncUrl = $resp.Headers["Azure-AsyncOperation"]
if (-not $asyncUrl) { $asyncUrl = $resp.Headers["Location"] }

Write-Host "Yêu cầu tạo máy ảo đã được chấp nhận. Đang theo dõi tiến trình khởi tạo..." -ForegroundColor Yellow

for ($i = 0; $i -lt 40; $i++) {
    Start-Sleep -Seconds 6
    $pollReq = [System.Net.WebRequest]::Create($asyncUrl)
    $pollReq.Headers["Authorization"] = "Bearer $Token"
    $pollResp = $pollReq.GetResponse()
    $sr = New-Object System.IO.StreamReader($pollResp.GetResponseStream())
    $json = $sr.ReadToEnd() | ConvertFrom-Json
    Write-Host "Tiến trình [$i]: $($json.status)"
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
