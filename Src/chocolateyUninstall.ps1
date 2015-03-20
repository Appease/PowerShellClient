try {

    . "$PSScriptRoot\PoshDevOps\Uninstall.ps1"

    Write-ChocolateySuccess 'PoshDevOps'

} catch {

    Write-ChocolateyFailure 'PoshDevOps' $_.Exception.Message

    throw 
}
