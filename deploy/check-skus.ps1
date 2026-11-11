param(
    [string]$Token,
    [string]$Sub = "1cf197a1-edc8-46c0-9f01-debae4b2ffe7",
    [string]$Location = "koreacentral"
)

$uri = "https://management.azure.com/subscriptions/$Sub/providers/Microsoft.Compute/skus?api-version=2021-07-01&`$filter=location eq '$Location'"
$headers = @{ "Authorization" = "Bearer $Token" }
$res = Invoke-RestMethod -Uri $uri -Headers $headers

$available = @()
foreach ($item in $res.value) {
    if ($item.resourceType -eq "virtualMachines") {
        $hasCapacityRestriction = $false
        foreach ($r in $item.restrictions) {
            if ($r.type -eq "Location" -or $r.reasonCode -eq "NotAvailableForSubscription") {
                $hasCapacityRestriction = $true
            }
        }
        if (-not $hasCapacityRestriction -and ($item.name -like "Standard_B*" -or $item.name -like "Standard_D2*")) {
            $available += [PSCustomObject]@{
                Name = $item.name
                Family = $item.family
                Restrictions = ($item.restrictions | ForEach-Object { "$($_.type):$($_.reasonCode)" }) -join "; "
            }
        }
    }
}

$available | Format-Table -AutoSize
