try {    
    
    . "$PSScriptRoot\PoshDevOps\Install.ps1"

} catch {

    Write-ChocolateyFailure 'PoshDevOps' $_.Exception.Message

    throw 
}
