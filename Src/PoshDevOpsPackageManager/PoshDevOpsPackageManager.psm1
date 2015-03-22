Import-Module "$PSScriptRoot\SemanticVersioning" -Force -Global

$DefaultPackageSources = @('https://www.myget.org/F/poshdevops')
$nugetExecutable = "$PSScriptRoot\nuget.exe"

function Install-PoshDevOpsPackage(
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
$Source = $defaultPackageSources,

[string]
[ValidateNotNullOrEmpty()]
[Parameter(
    ValueFromPipelineByPropertyName=$true)]
$ProjectRootDirPath='.'){

    $taskGroupDirPath = Resolve-Path "$ProjectRootDirPath\.PoshDevOps"
    $packagesDirPath = "$taskGroupDirPath\Packages"

    if([string]::IsNullOrWhiteSpace($Version)){

        $Version = Get-LatestPackageVersion -Source $Source -Id $Id

Write-Debug "using greatest available package version : $Version"
    
    }

    $initialOFS = $OFS
    
    try{

        $OFS = ';'        
        $nugetParameters = @('install','-Source',($Source|Out-String),'-Id',$Id,'-RepositoryPath',$packagesDirPath,'-NonInteractive')

Write-Debug `
@"
Invoking nuget:
& $nugetExecutable $($nugetParameters|Out-String)
"@
        & $nugetExecutable $nugetParameters

        # handle errors
        if ($LastExitCode -ne 0) {
            throw $Error
        }
    
    }
    Finally{
        $OFS = $initialOFS
    }

}

function Uninstall-PoshDevOpsPackageIfExists(
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
[ValidateNotNullOrEmpty()]
[Parameter(
    ValueFromPipelineByPropertyName=$true)]
$ProjectRootDirPath='.'){

    $taskGroupDirPath = Resolve-Path "$ProjectRootDirPath\.PoshDevOps"
    $packagesDirPath = "$taskGroupDirPath\Packages"

    $packageInstallationDir = "$packagesDirPath\$($Id).$($Version)"


    If(Test-Path $packageInstallationDir){
Write-Debug `
@"
Removing package at:
$packageInstallationDir
"@
        Remove-Item $packageInstallationDir -Recurse -Force -UseTransaction  
    }
    Else{
Write-Debug `
@"
No package to remove at:
$packageInstallationDir
"@
    }

}

function Get-LatestPackageVersion(

[string[]]
[Parameter(
    Mandatory=$true)]
$Source = $defaultPackageSources,

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

Export-ModuleMember -Variable DefaultPackageSources

Export-ModuleMember -Function Install-PoshDevOpsPackage
Export-ModuleMember -Function Uninstall-PoshDevOpsPackageIfExists
Export-ModuleMember -Function Get-LatestPackageVersion
