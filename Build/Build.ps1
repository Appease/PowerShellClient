function CreateChocolateyPackage(
[string][Parameter(Mandatory=$true)]$Version,
[string][Parameter(Mandatory=$true)]$Tools,
[string][Parameter(Mandatory=$true)]$OutputDirectory){
    # init working dir
    $workingDirPath = "$env:TEMP\Posh-CI-Build-Chocolatey"
    if(Test-Path $workingDirPath){
        Remove-Item $workingDirPath -Force -Recurse
    }
    New-Item $workingDirPath -ItemType Directory | Out-Null

    $chocolateyPackageToolsDirPath = "$workingDirPath\tools"
    New-Item $chocolateyPackageToolsDirPath -ItemType Directory | Out-Null

    # install chocolatey
    try{
        Get-Command choco -ErrorAction Stop | Out-Null
    }
    catch{             
        iex ((new-object net.webclient).DownloadString('https://chocolatey.org/install.ps1'))
    }

    Copy-Item `
    -Path "$PSScriptRoot\Chocolatey\posh-ci.nuspec" `
    -Destination $workingDirPath

    Copy-Item `
    -Path "$PSScriptRoot\Chocolatey\*" `
    -Destination $chocolateyPackageToolsDirPath `
    -Exclude 'posh-ci.nuspec'

    Copy-Item `
    -Path "$Tools\*" `
    -Destination $chocolateyPackageToolsDirPath `
    -Recurse
           
    $nuspecFilePath = "$workingDirPath\posh-ci.nuspec"

    # substitute vars into nuspec
    (gc $nuspecFilePath).Replace('$version$',$Version)|sc $nuspecFilePath

    Push-Location $OutputDirectory
    chocolatey pack $nuspecFilePath
    Pop-Location 

}

function Test(){
    # install chocolatey
    try{
        Get-Command choco -ErrorAction Stop | Out-Null
    }
    catch{             
        iex ((new-object net.webclient).DownloadString('https://chocolatey.org/install.ps1'))
    }

    # install pester
    try{
        Get-Command pester -ErrorAction Stop | Out-Null
    }
    catch{             
        iex ((new-object net.webclient).DownloadString('https://chocolatey.org/install.ps1'))
    }

    choco install pester
}

function Compile(
[string][Parameter(Mandatory=$true)]$Version,
[string][Parameter(Mandatory=$true)]$SourceDirPath,
[string][Parameter(Mandatory=$true)]$OutputDirPath){

    # Import-Module looks for module manifest with same name as containing folder
    $compiledPowerShellModuleDirPath = "$OutputDirPath\Posh-CI"
    New-Item $compiledPowerShellModuleDirPath -ItemType Directory | Out-Null

    # Copy the source files to the output
    Copy-Item `
    -Path "$SourceDirPath\*" `
    -Destination $compiledPowerShellModuleDirPath `
    -Recurse

    # Generate powershell module manifest
    New-ModuleManifest `
        -Path "$compiledPowerShellModuleDirPath\Posh-CI.psd1" `
        -ModuleVersion $Version `
        -Guid 15c1b906-eb08-4b0a-b4de-b5289cf35700 `
        -Author 'Chris Dostert' `
        -CompanyName 'TonightWe' `
        -Description 'A PowerShell environment for continous integration.' `
        -PowerShellVersion '3.0' `
        -DotNetFrameworkVersion '4.5' `
        -RootModule 'Posh-CI.psm1'
}

function New-Build(
[string][Parameter(Mandatory=$true)]$Version,
[string][Parameter(Mandatory=$true)]$ArtifactsDirPath,
[string]$SourceDirPath = "$PSScriptRoot\..\Src"){

    $ArtifactsDirPath = Resolve-Path $ArtifactsDirPath
    
    # init PowerShell module compiler output dir
    $compilerOutputDir = "$env:TEMP\Posh-CI-Compiler-Output"
    if(Test-Path $compilerOutputDir){
        Remove-Item $compilerOutputDir -Force -Recurse
    }
    New-Item $compilerOutputDir -ItemType Directory | Out-Null

    Compile -Version $Version -SourceDirPath $SourceDirPath -OutputDirPath $compilerOutputDir
    CreateChocolateyPackage -Version $Version -Tools $compilerOutputDir -OutputDirectory $ArtifactsDirPath
        
}
