try {    
    
    . "$PSScriptRoot\PoshDevOps\Install.ps1"

    Write-ChocolateySuccess 'Posh-CI'

} catch {

    Write-ChocolateyFailure 'Posh-CI' $_.Exception.Message

    throw 
}
