try {    
    
    . "$PSScriptRoot\Posh-CI\Install.ps1"

    Write-Host $env:PSModulePath
    Update-SessionEnvironment
    Write-Host $env:PSModulePath

    Import-Module Posh-CI -Force

    Write-ChocolateySuccess 'Posh-CI'

} catch {

    Write-ChocolateyFailure 'Posh-CI' $_.Exception.Message

    throw 
}
