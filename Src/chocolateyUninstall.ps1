try {

    . "$PSScriptRoot\Appease\Uninstall.ps1"

} catch {

    Write-ChocolateyFailure 'Appease' $_.Exception.Message

    throw 
}
