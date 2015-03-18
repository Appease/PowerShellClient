try {    
    
    . "$PSScriptRoot\PoshDevOps\Install.ps1"

    Write-ChocolateySuccess 'PoshDevOps'

} catch {

    Write-ChocolateyFailure 'PoshDevOps' $_.Exception.Message

    throw 
}
