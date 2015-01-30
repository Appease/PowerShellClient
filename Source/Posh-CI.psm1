function EnsureChocolateyInstalled(){
    # install chocolatey
    try{
        Get-Command choco -ErrorAction Stop | Out-Null
    }
    catch{             
        iex ((new-object net.webclient).DownloadString('https://chocolatey.org/install.ps1'))
    }
}

function Posh-CI(
[string]$RootDir=(Resolve-Path .)){
    
    $pathToPoshCIFile = "$RootDir\Posh-CI-File.ps1"
    if(Test-Path $pathToPoshCIFile){
        EnsureChocolateyInstalled
        choco install "$RootDir\Packages.config"
        . $pathToPoshCIFile
    }
    else{
        throw "File not found at: $pathToPoshCIFile"
    }    
}

Export-ModuleMember -Function Posh-CI
