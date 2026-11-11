param(
    [string]$Token,
    [string]$Sub = "1cf197a1-edc8-46c0-9f01-debae4b2ffe7",
    [string]$RgName = "DTDM"
)

$headers = @{ "Authorization" = "Bearer $Token" }
$uri = "https://management.azure.com/subscriptions/$Sub/resourceGroups/$RgName/providers/Microsoft.Network/networkSecurityGroups/node2-nsg?api-version=2021-05-01"
$res = Invoke-RestMethod -Uri $uri -Headers $headers
$res.properties.securityRules | Select-Object name, priority, direction, access, protocol, sourceAddressPrefix, destinationAddressPrefix, destinationPortRange | Format-Table -AutoSize
