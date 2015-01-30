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
    
    $pathToCIPlan = "$RootDir\CI-Plan.ps1"
    if(Test-Path $pathToCIPlan){
        EnsureChocolateyInstalled
        choco install "$RootDir\CI-Deps.xml"
        . $pathToCIPlan
    }
    else{
        throw "File not found at: $pathToCIPlan"
    }    
}

Export-ModuleMember -Function Posh-CI
