try {    
    
    . "$PSScriptRoot\Appease.Client\Install.ps1"

} catch {

    Write-ChocolateyFailure 'appease.client.powershell' $_.Exception.Message

    throw 
}
