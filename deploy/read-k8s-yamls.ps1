param(
    [string]$Token,
    [string]$Sub = "1cf197a1-edc8-46c0-9f01-debae4b2ffe7",
    [string]$RgName = "DTDM",
    [string]$VmName = "node1"
)

$headers = @{ "Authorization" = "Bearer $Token"; "Content-Type" = "application/json" }
$body = @{
    commandId = "RunShellScript"
    script = @(
        "ls -la /root/k8s",
        "cat /root/k8s/*.yaml",
        "cat /root/k8s/*.sh 2>/dev/null || true",
        "cat /root/k8s/*.md 2>/dev/null || true"
    )
} | ConvertTo-Json

$uri = "https://management.azure.com/subscriptions/$Sub/resourceGroups/$RgName/providers/Microsoft.Compute/virtualMachines/$VmName/runCommand?api-version=2021-11-01"

$wr = [System.Net.WebRequest]::Create($uri)
$wr.Method = "POST"
$wr.Headers["Authorization"] = "Bearer $Token"
$wr.ContentType = "application/json"
$bytes = [System.Text.Encoding]::UTF8.GetBytes($body)
$wr.ContentLength = $bytes.Length
$s = $wr.GetRequestStream()
$s.Write($bytes, 0, $bytes.Length)
$s.Close()
$resp = $wr.GetResponse()
$loc = $resp.Headers["Location"]
$async = $resp.Headers["Azure-AsyncOperation"]
$poll = if ($async) { $async } else { $loc }

for ($i = 0; $i -lt 15; $i++) {
    Start-Sleep -Seconds 3
    $r = Invoke-RestMethod -Uri $poll -Headers $headers
    if ($r.status -eq "Succeeded") {
        $final = Invoke-RestMethod -Uri $loc -Headers $headers
        Write-Host $final.value[0].message
        break
    }
}
