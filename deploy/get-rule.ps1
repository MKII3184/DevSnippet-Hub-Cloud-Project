param(
    [string]$Token,
    [string]$Sub = "1cf197a1-edc8-46c0-9f01-debae4b2ffe7",
    [string]$RgName = "DTDM"
)

$headers = @{ "Authorization" = "Bearer $Token" }
$uri = "https://management.azure.com/subscriptions/$Sub/resourceGroups/$RgName/providers/Microsoft.Network/networkSecurityGroups/node2-nsg?api-version=2021-05-01"
$res = Invoke-RestMethod -Uri $uri -Headers $headers
$rule = $res.properties.securityRules | Where-Object { $_.name -eq 'nodeport30080' }
$rule.properties | ConvertTo-Json
