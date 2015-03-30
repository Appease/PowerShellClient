try {    
    
    . "$PSScriptRoot\Appease\Install.ps1"

} catch {

    Write-ChocolateyFailure 'Appease' $_.Exception.Message

    throw 
}
