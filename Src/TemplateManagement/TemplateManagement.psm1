Import-Module "$PSScriptRoot\Versioning"
Import-Module "$PSScriptRoot\..\Pson"

$DefaultTemplateSources = @('https://www.myget.org/F/appease')
$NugetExecutable = "$PSScriptRoot\nuget.exe"
$ChocolateyExecutable = "chocolatey"

function Get-DevOpTaskTemplateLatestVersion(

    [string[]]
    [Parameter(
        Mandatory=$true)]
    $Source = $DefaultTemplateSources,

    [string]
    [ValidateNotNullOrEmpty()]
    [Parameter(
        Mandatory=$true)]
    $Id){
    
    $versions = @()

    foreach($templateSource in $Source){
        $uri = "$templateSource/api/v2/package-versions/$Id"
Write-Debug "Attempting to fetch template versions:` uri: $uri "
        $versions = $versions + (Invoke-RestMethod -Uri $uri)
Write-Debug "response from $uri was: ` $versions"
    }
    if(!$versions -or ($versions.Count -lt 1)){
throw "no versions of $Id could be located.` searched: $Source"
    }

Write-Output ([Array](Get-SortedSemanticVersions -InputArray $versions -Descending))[0]
}

function New-DevOpTaskTemplateSpec(
    
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
    $TemplateName,

    [string]
    [ValidateScript({ if(!$_){$true}else{$_ | Test-SemanticVersion} })]
    [Parameter(
        ValueFromPipelineByPropertyName=$true)]
    $TemplateVersion,
    
    [string]
    [ValidateNotNullOrEmpty()]
    [Parameter(
        ValueFromPipelineByPropertyName=$true)]
    $TemplateDescription,
    
    [Hashtable[]]
    [Parameter(
        ValueFromPipelineByPropertyName=$true)]
    $TemplateContributor,
    
    [System.Uri]
    [Parameter(
        ValueFromPipelineByPropertyName=$true)]
    $TemplateProjectUrl,
    
    [string[]]
    [Parameter(
        ValueFromPipelineByPropertyName=$true)]
    $TemplateTag,
    
    [Hashtable]
    [Parameter(
        ValueFromPipelineByPropertyName=$true)]
    $TemplateLicense,
    
    [Hashtable]
    [Parameter(
        ValueFromPipelineByPropertyName=$true)]
    $TemplateDependency,
    
    [Hashtable[]]
    [ValidateNotNullOrEmpty()]
    [Parameter(
        ValueFromPipelineByPropertyName=$true,
        Mandatory=$true)]
    $TemplateFile){

    $TemplateSpecFilePath = "$OutputDirPath\TemplateSpec.psd1"
           
    # guard against unintentionally overwriting existing devop task template spec
    if(!$Force.IsPresent -and (Test-Path $TemplateSpecFilePath)){
throw `
@"
Template spec already exists at: $(Resolve-Path $TemplateSpecFilePath)
to overwrite the existing template spec use the -Force parameter
"@
    }

Write-Debug `
@"
Creating template spec file at:
$TemplateSpecFilePath
"@

    New-Item -Path $TemplateSpecFilePath -ItemType File -Force:$Force      

    $TemplateSpec = @{
        Name = $TemplateName;
        Version = $TemplateVersion;
        Description = $TemplateDescription;
        Contributors = $TemplateContributor;
        ProjectUrl = $TemplateProjectUrl;
        Tags = $TemplateTag;
        License = $TemplateLicense;
        Dependencies = $TemplateDependency;
        Files = $TemplateFile}

    Set-Content $TemplateSpecFilePath -Value (ConvertTo-Pson -InputObject $TemplateSpec -Depth 12 -Layers 12 -Strict) -Force
    
}

function Get-DevOpTaskTemplateInstallDirPath(

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

    Resolve-Path "$ProjectRootDirPath\.Appease\templates\$Name.$Version" | Write-Output
    
}

function Get-DevOpTaskTemplateSpec(

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
        Parses a devop task template spec file
    #>

    $TemplateInstallDirPath = Get-DevOpTaskTemplateInstallDirPath -Name $Name -Version $Version -ProjectRootDirPath $ProjectRootDirPath
    $TemplateSpecFilePath = Join-Path -Path $TemplateInstallDirPath -ChildPath "\TemplateSpec.psd1"
    Get-Content $TemplateSpecFilePath | Out-String | ConvertFrom-Pson | Write-Output

}

function Install-DevOpTaskTemplate(

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
        Installs a devop task template to an environment if it's not already installed
    #>

    $TemplatesDirPath = "$ProjectRootDirPath\.Appease\templates"

    if([string]::IsNullOrWhiteSpace($Version)){

        $Version = Get-LatestTemplateVersion -Source $Source -Id $Id

Write-Debug "using greatest available template version : $Version"
    
    }

    $initialOFS = $OFS
    
    try{

        $OFS = ';'        
        $NugetParameters = @('install',$Id,'-Source',($Source|Out-String),'-OutputDirectory',$TemplatesDirPath,'-Version',$Version,'-NonInteractive')

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
    $ChocolateyDependencies = (Get-DevOpTaskTemplateSpec -Name $Id -Version $Version -ProjectRootDirPath $ProjectRootDirPath).Dependencies.Chocolatey
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

function Uninstall-DevOpTaskTemplate(

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
        Uninstalls a devop task template from an environment if it's installed
    #>

    $taskGroupDirPath = Resolve-Path "$ProjectRootDirPath\.Appease"
    $templatesDirPath = "$taskGroupDirPath\templates"

    $templateInstallationDir = "$templatesDirPath\$($Id).$($Version)"


    If(Test-Path $templateInstallationDir){
Write-Debug `
@"
Removing template at:
$templateInstallationDir
"@
        Remove-Item $templateInstallationDir -Recurse -Force
    }
    Else{
Write-Debug `
@"
No template to remove at:
$templateInstallationDir
"@
    }

    #TODO: UNINSTALL DEPENDENCIES ?

}

Export-ModuleMember -Variable 'DefaultTemplateSources'
Export-ModuleMember -Function @(
                                'Get-DevOpTaskTemplateLatestVersion'
                                'New-DevOpTaskTemplateSpec',                                
                                'Install-DevOpTaskTemplate',
                                'Uninstall-DevOpTaskTemplate')
