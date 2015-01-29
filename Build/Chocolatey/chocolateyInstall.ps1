try {

    . "$PSScriptRoot\Posh-Grunt\Install.ps1"

    Write-ChocolateySuccess 'Posh-Grunt'

} catch {

    Write-ChocolateyFailure 'Posh-Grunt' $_.Exception.Message

    throw 
}
