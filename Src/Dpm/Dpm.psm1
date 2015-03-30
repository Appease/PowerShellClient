Import-Module "$PSScriptRoot\Versioning"
Import-Module "$PSScriptRoot\..\Pson"

$DefaultPackageSources = @('https://www.myget.org/F/appease')
$NugetExecutable = "$PSScriptRoot\nuget.exe"
$ChocolateyExecutable = "chocolatey"

function Get-DpmLatestPackageVersion(

[string[]]
[Parameter(
    Mandatory=$true)]
$Source = $DefaultPackageSources,

[string]
[ValidateNotNullOrEmpty()]
[Parameter(
    Mandatory=$true)]
$Id){
    
    $versions = @()

    foreach($packageSource in $Source){
        $uri = "$packageSource/api/v2/package-versions/$Id"
Write-Debug "Attempting to fetch package versions:` uri: $uri "
        $versions = $versions + (Invoke-RestMethod -Uri $uri)
Write-Debug "response from $uri was: ` $versions"
    }
    if(!$versions -or ($versions.Count -lt 1)){
throw "no versions of $Id could be located.` searched: $Source"
    }

Write-Output ([Array](Get-SortedSemanticVersions -InputArray $versions -Descending))[0]
}

function New-DpmSpec(
    
    [string]
    [ValidateScript({Test-Path $_ -PathType Container})]
    [Parameter(
        ValueFromPipelineByPropertyName=$true)]
    $OutputDirPath = '.',

    [switch]
    [Parameter(
        ValueFromPipelineByPropertyName=$true)]
    $Force,

    [string]
    [ValidateNotNullOrEmpty()]
    [Parameter(
        ValueFromPipelineByPropertyName=$true,
        Mandatory=$true)]
    $PackageName,

    [string]
    [ValidateScript({ if(!$_){$true}else{$_ | Test-SemanticVersion} })]
    [Parameter(
        ValueFromPipelineByPropertyName=$true)]
    $PackageVersion,
    
    [string]
    [ValidateNotNullOrEmpty()]
    [Parameter(
        ValueFromPipelineByPropertyName=$true)]
    $PackageDescription,
    
    [Hashtable[]]
    [Parameter(
        ValueFromPipelineByPropertyName=$true)]
    $PackageContributor,
    
    [System.Uri]
    [Parameter(
        ValueFromPipelineByPropertyName=$true)]
    $PackageProjectUrl,
    
    [string[]]
    [Parameter(
        ValueFromPipelineByPropertyName=$true)]
    $PackageTag,
    
    [Hashtable]
    [Parameter(
        ValueFromPipelineByPropertyName=$true)]
    $PackageLicense,
    
    [Hashtable]
    [Parameter(
        ValueFromPipelineByPropertyName=$true)]
    $PackageDependency,
    
    [Hashtable[]]
    [ValidateNotNullOrEmpty()]
    [Parameter(
        ValueFromPipelineByPropertyName=$true,
        Mandatory=$true)]
    $PackageFile){

    $PackageSpecFilePath = "$OutputDirPath\PackageSpec.psd1"
           
    # guard against unintentionally overwriting existing package spec
    if(!$Force.IsPresent -and (Test-Path $PackageSpecFilePath)){
throw `
@"
Package spec already exists at: $(Resolve-Path $PackageSpecFilePath)
to overwrite the existing package spec use the -Force parameter
"@
    }

Write-Debug `
@"
Creating package spec file at:
$PackageSpecFilePath
"@

    New-Item -Path $PackageSpecFilePath -ItemType File -Force:$Force      

    $PackageSpec = @{
        Name = $PackageName;
        Version = $PackageVersion;
        Description = $PackageDescription;
        Contributors = $PackageContributor;
        ProjectUrl = $PackageProjectUrl;
        Tags = $PackageTag;
        License = $PackageLicense;
        Dependencies = $PackageDependency;
        Files = $PackageFile}

    Set-Content $PackageSpecFilePath -Value (ConvertTo-Pson -InputObject $PackageSpec -Depth 12 -Layers 12 -Strict) -Force
    
}

function Get-DpmPackageInstallDirPath(

[string]
[ValidateNotNullOrEmpty()]
[Parameter(
    Mandatory=$true,
    ValueFromPipelineByPropertyName=$true)]
$Name,

[string]
[ValidateNotNullOrEmpty()]
[Parameter(
    Mandatory=$true,
    ValueFromPipelineByPropertyName=$true)]
$Version,

[string]
[ValidateScript({Test-Path $_ -PathType Container})]
[Parameter(
    ValueFromPipelineByPropertyName=$true)]
$ProjectRootDirPath = '.'){

    Resolve-Path "$ProjectRootDirPath\.Appease\packages\$Name.$Version\PackageSpec.psd1" | Write-Output
    
}

function Get-DpmPackageSpec(

[string]
[ValidateNotNullOrEmpty()]
[Parameter(
    Mandatory=$true,
    ValueFromPipelineByPropertyName=$true)]
$Name,

[string]
[ValidateNotNullOrEmpty()]
[Parameter(
    Mandatory=$true,
    ValueFromPipelineByPropertyName=$true)]
$Version,

[string]
[ValidateScript({Test-Path $_ -PathType Container})]
[Parameter(
    ValueFromPipelineByPropertyName=$true)]
$ProjectRootDirPath = '.'){

    <#
        .SYNOPSIS
        Parses a DevOp task package spec file
    #>

    $PackageSpecFilePath = Get-DpmPackageInstallDirPath -Name $Name -Version $Version -ProjectRootDirPath $ProjectRootDirPath
    Get-Content $PackageSpecFilePath | Out-String | ConvertFrom-Pson | Write-Output

}

function Install-DpmPackage(

[string]
[ValidateNotNullOrEmpty()]
[Parameter(
    Mandatory=$true,
    ValueFromPipelineByPropertyName=$true)]
$Id,

[string]
[Parameter(
    ValueFromPipelineByPropertyName=$true)]
$Version,

[string[]]
[ValidateCount( 1, [Int]::MaxValue)]
[ValidateNotNullOrEmpty()]
[Parameter(
    ValueFromPipelineByPropertyName=$true)]
$Source,

[string]
[ValidateScript({Test-Path $_ -PathType Container})]
[Parameter(
    ValueFromPipelineByPropertyName=$true)]
$ProjectRootDirPath='.'){

    <#
        .SYNOPSIS
        Installs a task package to an environment if it's not already installed
    #>

    $PackagesDirPath = "$ProjectRootDirPath\.Appease\packages"

    if([string]::IsNullOrWhiteSpace($Version)){

        $Version = Get-LatestPackageVersion -Source $Source -Id $Id

Write-Debug "using greatest available package version : $Version"
    
    }

    $initialOFS = $OFS
    
    try{

        $OFS = ';'        
        $NugetParameters = @('install',$Id,'-Source',($Source|Out-String),'-OutputDirectory',$PackagesDirPath,'-Version',$Version,'-NonInteractive')

Write-Debug `
@"
Invoking nuget:
& $NugetExecutable $($NugetParameters|Out-String)
"@
        & $NugetExecutable $NugetParameters

        # handle errors
        if ($LastExitCode -ne 0) {
            throw $Error
        }
    
    }
    Finally{
        $OFS = $initialOFS
    }

    # install chocolatey dependencies
    $ChocolateyDependencies = (Get-DpmPackageSpec -Name $Id -Version $Version -ProjectRootDirPath $ProjectRootDirPath).Dependencies.Chocolatey
    foreach($ChocolateyDependency in $ChocolateyDependencies){
        $ChocolateyParameters = @('install',$ChocolateyDependency.Id,'--confirm')
        
        if($ChocolateyDependency.Source){
            $ChocolateyParameters += @('--source',$ChocolateyDependency.Source)
        }

        if($ChocolateyDependency.Version){
            $ChocolateyParameters += @('--version',$ChocolateyDependency.Version)
        }

        if($ChocolateyDependency.InstallArguments){
            $ChocolateyParameters += @('--install-arguments',$ChocolateyDependency.InstallArguments)
        }
        
        if($ChocolateyDependency.OverrideArguments){
            $ChocolateyParameters += @('--override-arguments')
        }

        if($ChocolateyDependency.PackageParameters){
            $ChocolateyParameters += @('--package-parameters',$ChocolateyDependency.PackageParameters)
        }

        if($ChocolateyDependency.AllowMultipleVersions){
            $ChocolateyParameters += @('--allow-multiple-versions')
        }

Write-Debug `
@"
Invoking chocolatey:
& $ChocolateyExecutable $($ChocolateyParameters|Out-String)
"@

        & $ChocolateyExecutable $ChocolateyParameters

        # handle errors
        if ($LastExitCode -ne 0) {
            throw $Error
        }

    }

}

function Uninstall-DpmPackage(

[string]
[ValidateNotNullOrEmpty()]
[Parameter(
    Mandatory=$true,
    ValueFromPipelineByPropertyName=$true)]
$Id,

[string]
[ValidateNotNullOrEmpty()]
[Parameter(
    Mandatory=$true,
    ValueFromPipelineByPropertyName=$true)]
$Version,

[string]
[ValidateScript({Test-Path $_ -PathType Container})]
[Parameter(
    ValueFromPipelineByPropertyName=$true)]
$ProjectRootDirPath='.'){

    <#
        .SYNOPSIS
        Uninstalls a task package from an environment if it's installed
    #>

    $taskGroupDirPath = Resolve-Path "$ProjectRootDirPath\.Appease"
    $packagesDirPath = "$taskGroupDirPath\packages"

    $packageInstallationDir = "$packagesDirPath\$($Id).$($Version)"


    If(Test-Path $packageInstallationDir){
Write-Debug `
@"
Removing package at:
$packageInstallationDir
"@
        Remove-Item $packageInstallationDir -Recurse -Force
    }
    Else{
Write-Debug `
@"
No package to remove at:
$packageInstallationDir
"@
    }

    #TODO: UNINSTALL DEPENDENCIES ?

}

Export-ModuleMember -Variable 'DefaultPackageSources'
Export-ModuleMember -Function @(
                                'Get-DpmLatestPackageVersion'
                                'New-DpmSpec',
                                'Get-DpmPackageSpec',                                
                                'Install-DpmPackage',
                                'Uninstall-DpmPackage')
