try {

    . "$PSScriptRoot\PoshDevOps\Uninstall.ps1"

    Write-ChocolateySuccess 'Posh-CI'

} catch {

    Write-ChocolateyFailure 'Posh-CI' $_.Exception.Message

    throw 
}
