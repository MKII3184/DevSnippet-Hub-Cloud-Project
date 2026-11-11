param(
    [string]$Token,
    [string]$Sub = "1cf197a1-edc8-46c0-9f01-debae4b2ffe7",
    [string]$Location = "koreacentral"
)

$uri = "https://management.azure.com/subscriptions/$Sub/providers/Microsoft.Compute/locations/$Location/usages?api-version=2021-07-01"
$headers = @{ "Authorization" = "Bearer $Token" }
$res = Invoke-RestMethod -Uri $uri -Headers $headers
$res.value | Where-Object { $_.limit -gt 0 } | Select-Object @{N="Name"; E={$_.name.localizedValue}}, currentValue, limit | Format-Table -AutoSize
