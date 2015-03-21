try {

    . "$PSScriptRoot\Uninstall.ps1"

} catch {

    Write-ChocolateyFailure 'PoshDevOps' $_.Exception.Message

    throw 
}
