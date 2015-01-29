function EnsureChocolateyInstalled(){
    # install chocolatey
    try{
        Get-Command choco -ErrorAction Stop | Out-Null
    }
    catch{             
        iex ((new-object net.webclient).DownloadString('https://chocolatey.org/install.ps1'))
    }
}

function SetupBuildArtifactsDirectory(
[string]$Path,
[bool]$CleanIfExists = $true){
    if((Test-Path -Path $Path) -and $CleanIfExists){
        Remove-Item $Path -Force -Recurse
    }

    New-Item $Path -ItemType "Directory"
}

function New-Build(
$PathToSourceDirectory= (Convert-Path .),
$PathToBuildArtifactsDirectory = ".\Build-Artifacts",
$PathToMsBuildExe = "C:\Program Files (x86)\MSBuild\14.0\Bin\MSBuild.exe"){
    EnsureChocolateyInstalled
    SetupBuildArtifactsDirectory -Path $PathToBuildArtifactsDirectory    
    Posh-Grunt-MsBuild\Invoke -PathToParentDirectory $PathToSourceDirectory -PathToMsBuildExe $PathToMsBuildExe -Recurse
    Posh-Grunt-NuGet\Invoke-Pack -PathToParentDirectory $PathToSourceDirectory -PathToBuildArtifactsDirectory $PathToBuildArtifactsDirectory -Recurse
}

Export-ModuleMember -Function New-Build
