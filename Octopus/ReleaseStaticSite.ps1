Set-PSDebug -Trace 1

$path = $OctopusParameters["Path"]
$cfZone = $OctopusParameters["CloudFlare.Zone"]
$cfToken = $OctopusParameters["CloudFlare.Token"]
$azSubscriptionId = $OctopusParameters["Azure.SubscriptionId"]
$azTenantId = $OctopusParameters["Azure.TenantId"]
$azClientId = $OctopusParameters["Azure.ClientId"]
$azClientSecret = $OctopusParameters["Azure.ClientSecret"]
$azResourceGroup = $OctopusParameters["Azure.ResourceGroup"]
$azCDNProfile = $OctopusParameters["Azure.CDNProfile"]
$azCDNEndpoint = $OctopusParameters["Azure.CDNEndpoint"]

$artifact = $OctopusParameters["Artifact"]
$staticFolderContent = if ($artifact) { $artifact } else { "site" }

$here = Pwd
Write-Host $here

$json = $OctopusParameters | ConvertTo-Json
Write-Host $json
ls

rm -rf $path
mv "staticSite/$($staticFolderContent)" $path

if ($cfZone) {
    $headers = @{
        "Authorization"="Bearer $($cfToken)";
        "Content-Type"="application/json"
    }

    $body = @{
        purge_everything=$true
    } | ConvertTo-Json

    Invoke-RestMethod -Uri "https://api.cloudflare.com/client/v4/zones/$($cfZone)/purge_cache" -Method 'DELETE' -Headers $headers -Body $body
}

if ($azCDNEndpoint) {
    $body = @{
        grant_type="client_credentials"
        client_id=$azClientId
        client_secret=$azClientSecret
        resource="https://management.core.windows.net/"
    }

    $url = "https://login.windows.net/$($azTenantId)/oauth2/token"

    $response = Invoke-WebRequest -Uri $url -Method POST -Body $body -ContentType "application/x-www-form-urlencoded"
    $data = $response | ConvertFrom-Json
    $accessToken = $data.access_token

    $body = @{
        contentPaths = ,"/*"
    } | ConvertTo-Json

    $headers = @{
        "Authorization"="Bearer $($accessToken)";
        "Content-Type"="application/json; charset=utf-8"
    }

    $url = "https://management.azure.com/subscriptions/$($azSubscriptionId)/resourceGroups/$($azResourceGroup)/providers/Microsoft.Cdn/profiles/$($azCDNProfile)/endpoints/$($azCDNEndpoint)/purge?api-version=2019-04-15"

    $response = Invoke-WebRequest -Uri $url -Method 'POST' -Headers $headers -Body $body
    Write-Output "StatusCode: $($response.StatusCode)"
}
