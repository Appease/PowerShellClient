try {

    . "$PSScriptRoot\Appease.Client\Uninstall.ps1"

} catch {

    Write-ChocolateyFailure 'appease.client.powershell' $_.Exception.Message

    throw 
}
