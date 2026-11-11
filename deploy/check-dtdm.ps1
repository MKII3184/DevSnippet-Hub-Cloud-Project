param(
    [string]$Token,
    [string]$Sub = "1cf197a1-edc8-46c0-9f01-debae4b2ffe7"
)

$headers = @{ "Authorization" = "Bearer $Token" }
$uri = "https://management.azure.com/subscriptions/$Sub/resourceGroups/DTDM/providers/Microsoft.Compute/virtualMachines?api-version=2021-11-01"
$res = Invoke-RestMethod -Uri $uri -Headers $headers
foreach ($vm in $res.value) {
    Write-Host "VM Name: $($vm.name) | Location: $($vm.location) | Size: $($vm.properties.hardwareProfile.vmSize)"
}
