using namespace System.Net

param($Request, $TriggerMetadata)

$ErrorActionPreference = "Stop"
Write-Host "PowerShell HTTP trigger function processed a request."
$azStorageSASToken = $Request.Body.azStorageSASToken

if ($azStorageSASToken) {
    try {
        Write-Host "Getting access token and connecting to Azure account"
        $accessToken = ""
        $kvAccessToken = ""
        $clientId = ""
        if (Test-Path env:\accesstoken) {
            $accessToken = $env:accesstoken
            $kvAccessToken = $env:kvaccesstoken
            $clientId = $env:clientid
        }
        else {
            $resourceURI = "https://management.core.windows.net/"
            $tokenAuthURI = $env:IDENTITY_ENDPOINT + "?resource=$resourceURI&api-version=2019-08-01"
            $tokenResponse = Invoke-RestMethod -Method Get -Headers @{"X-IDENTITY-HEADER" = "$env:IDENTITY_HEADER" } -Uri $tokenAuthURI
            $accessToken = $tokenResponse.access_token
            $clientId = $tokenResponse.client_id

            $resourceURI = "https://vault.azure.net"
            $tokenAuthURI = $env:IDENTITY_ENDPOINT + "?resource=$resourceURI&api-version=2019-08-01"
            $tokenResponse = Invoke-RestMethod -Method Get -Headers @{"X-IDENTITY-HEADER" = "$env:IDENTITY_HEADER" } -Uri $tokenAuthURI
            $kvAccessToken = $tokenResponse.access_token
        }
        Connect-AzAccount -AccessToken $accessToken -AccountId $clientId -KeyVaultAccessToken $kvAccessToken

        $secretvalue = ConvertTo-SecureString $azStorageSASToken -AsPlainText -Force
        $expires = (Get-Date).AddDays(21).ToUniversalTime()
        Write-Host "Setting secret $($env:SecretName) in key vault $($env:KeyVaultName), expiring at $($expires.ToString())"
        Set-AzKeyVaultSecret -VaultName $env:KeyVaultName -Name $env:SecretName -SecretValue $secretvalue -Expires $expires

        Write-Host "Success"
        Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
                StatusCode = [HttpStatusCode]::OK
            })   
    }
    catch {
        Write-Host "Caught an exception: $($_.ToString())"
        Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
                StatusCode = [HttpStatusCode]::BadRequest
                Body       = @{
                    "Message"    = $_.ToString()
                    "StackTrace" = $_.ScriptStackTrace
                }
            })
    } 
}
else {
    Write-Host "Didn't find the expected param"
    Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
            StatusCode = [HttpStatusCode]::BadRequest
        })    
}

