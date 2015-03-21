try {

    . "$PSScriptRoot\PoshDevOps\Uninstall.ps1"

} catch {

    Write-ChocolateyFailure 'PoshDevOps' $_.Exception.Message

    throw 
}
