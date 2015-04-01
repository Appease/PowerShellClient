Import-Module "$PSScriptRoot\Versioning"

$DefaultTemplateSources = @('https://www.myget.org/F/appease')
$NuGetCommand = "nuget"
$ChocolateyCommand = "chocolatey"

function Get-AppeaseTaskTemplateLatestVersion(

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

function New-NuGetPackage(
    [string]
    $NuspecFilePath){
    
    $NugetParameters = @('pack',$NuspecFilePath)

Write-Debug `
@"
Invoking nuget:
& $NuGetCommand $($NugetParameters|Out-String)
"@
    & $NuGetCommand $NuGetParameters

    # handle errors
    if ($LastExitCode -ne 0) {
        throw $Error
    }
}

function Publish-NuGetPackage(
    [string]
    $NupkgFilePath,
    [string]

    [string]
    $SourcePathOrUrl,

    $ApiKey){
    $NuGetParameters = @('push',$NupkgFilePath,'-Source',$SourcePathOrUrl)

    if($ApiKey){
        $NuGetParameters = $NuGetParameters + @('-ApiKey',$ApiKey)
    }

Write-Debug `
@"
Invoking nuget:
$NuGetCommand $($NuGetParameters|Out-String)
"@
    & $NuGetCommand $NuGetParameters
        
    # handle errors
    if ($LastExitCode -ne 0) {
        throw $Error
        
    }
}

function Publish-AppeaseTaskTemplate(
    
    [string]    
    [ValidateNotNullOrEmpty()]
    [Parameter(
        Mandatory=$true,
        ValueFromPipelineByPropertyName = $true)]
    $Name,
    
    [string]
    [Parameter(
        ValueFromPipelineByPropertyName = $true)]
    $Description,
    
    [string]
    [ValidateScript({
        if($_ | Test-SemanticVersion){
            $true
        }
        else{            
            throw "'$_' is not a valid Semantic Version"
        }
    })]
    [Parameter(
        Mandatory=$true)]
    $Version,
    
    [Hashtable[]]
    [Parameter(
        ValueFromPipelineByPropertyName = $true)]
    $Contributor,
    
    [Hashtable[]]
    [Parameter(
        ValueFromPipelineByPropertyName = $true)]
    $File,

    [Hashtable[]]
    [Parameter(
        ValueFromPipelineByPropertyName = $true)]
    $Dependency,
    
    [System.Uri]
    [Parameter(
        ValueFromPipelineByPropertyName = $true)]
    $IconUrl,

    [System.Uri]
    [Parameter(
        ValueFromPipelineByPropertyName = $true)]
    $ProjectUrl,

    [string[]]
    [Parameter(
        ValueFromPipelineByPropertyName = $true)]
    $Tags,
    
    [string]
    [ValidateNotNullOrEmpty()]
    [Parameter(
        ValueFromPipelineByPropertyName = $true)]
    $DestinationPathOrUrl = $DefaultTemplateSources[0],

    [string]
    [Parameter(
        ValueFromPipelineByPropertyName = $true)]
    $ApiKey,

    [string]
    [ValidateScript({Test-Path $_ -PathType Container})]
    [Parameter(
        ValueFromPipelineByPropertyName=$true)]
    $ProjectRootDirPath = '.'){

    $DependenciesFileName = "$([Guid]::NewGuid()).json"
    
    # generate nuspec xml
$nuspecXmlString =
@"
<?xml version="1.0"?>
<package>
  <metadata>
    <id>$Name</id>
    <version>$Version</version>
    <authors>$([string]::Join(',',($Contributor|%{$_.Name})))</authors>
    <projectUrl>$ProjectUrl</projectUrl>
    <iconUrl>$([string]$IconUrl)</iconUrl>
    <requireLicenseAcceptance>false</requireLicenseAcceptance>
    <description>$Description</description>
    <tags>$(if($Tags){[string]::Join(" ",$Tags)})</tags>
  </metadata>
  <files>
    <file src="$DependenciesFileName" target="dependencies.json"/>
    $([string]::Join([System.Environment]::NewLine,($File|%{"<file src=`"$($_.Include)`" target=`"bin\$($_.Destination)`" exclude=`"$([string]::Join(';',($DependenciesFileName,$_.Exclude)))`" />"})))
  </files>
</package>
"@
        $NuspecXml = [xml]($nuspecXmlString)

        Try
        {
            # generate a nuspec file
            $NuspecFilePath = Join-Path -Path $ProjectRootDirPath -ChildPath "$([Guid]::NewGuid()).nuspec"
            New-Item -ItemType File -Path $NuspecFilePath -Force
            $NuspecXml.Save($(Resolve-Path $NuspecFilePath))

            # generate a Dependencies file
            $DependenciesFilePath = Join-Path -Path $ProjectRootDirPath -ChildPath $DependenciesFileName
            New-Item -ItemType File -Path $DependenciesFilePath -Force
            $Dependency | ConvertTo-Json | sc -Path $DependenciesFilePath -Force

            # build a nupkg file
            New-NuGetPackage -NuspecFilePath $NuspecFilePath
            $NuPkgFilePath = Join-Path -Path $ProjectRootDirPath -ChildPath "$Name.$Version.nupkg"

            # publish nupkg file
            Publish-NuGetPackage -NupkgFilePath $NuPkgFilePath -SourcePathOrUrl $DestinationPathOrUrl -ApiKey $ApiKey
            
        }
        Finally{
            Remove-Item $NuspecFilePath -Force
            Remove-Item $DependenciesFilePath -Force
            Remove-Item $NuPkgFilePath -Force
        }

}

function Get-AppeaseTaskTemplateInstallDirPath(

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
    $ProjectRootDirPath = '.'){

    Resolve-Path "$ProjectRootDirPath\.Appease\Templates\$Id.$Version" | Write-Output
    
}

function Get-AppeaseTaskTemplateDependencies(

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
        Parses a dependencies.json file
    #>

    $TemplateInstallDirPath = Get-AppeaseTaskTemplateInstallDirPath -Name $Name -Version $Version -ProjectRootDirPath $ProjectRootDirPath
    $TemplateDependenciesFilePath = Join-Path -Path $TemplateInstallDirPath -ChildPath "\dependencies.json"
    Get-Content $TemplateDependenciesFilePath | Out-String | ConvertFrom-Json | Write-Output

}

function Install-AppeaseTaskTemplate(

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
        Installs a task template to an environment if it's not already installed
    #>

    $TemplatesDirPath = "$ProjectRootDirPath\.Appease\Templates"

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
& $NuGetCommand $($NugetParameters|Out-String)
"@
        & $NuGetCommand $NugetParameters

        # handle errors
        if ($LastExitCode -ne 0) {
            throw $Error
        }
    
    }
    Finally{
        $OFS = $initialOFS
    }

    # install chocolatey dependencies
    $ChocolateyDependencies = (Get-AppeaseTaskTemplateDependencies -Name $Id -Version $Version -ProjectRootDirPath $ProjectRootDirPath).Chocolatey
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
& $ChocolateyCommand $($ChocolateyParameters|Out-String)
"@

        & $ChocolateyCommand $ChocolateyParameters

        # handle errors
        if ($LastExitCode -ne 0) {
            throw $Error
        }

    }

}

function Uninstall-AppeaseTaskTemplate(

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
        Uninstalls a task template from an environment if it's installed
    #>

    $TaskTemplateInstallationDir = Get-AppeaseTaskTemplateInstallDirPath -Id $Id -Version $Version -ProjectRootDirPath $ProjectRootDirPath


    If(Test-Path $TaskTemplateInstallationDir){
Write-Debug `
@"
Removing template at:
$TaskTemplateInstallationDir
"@
        Remove-Item $TaskTemplateInstallationDir -Recurse -Force
    }
    Else{
Write-Debug `
@"
No template to remove at:
$TaskTemplateInstallationDir
"@
    }

    #TODO: UNINSTALL DEPENDENCIES ?

}

Export-ModuleMember -Variable 'DefaultTemplateSources'
Export-ModuleMember -Function @(
                                'Get-AppeaseTaskTemplateLatestVersion',
                                'Get-AppeaseTaskTemplateInstallDirPath'
                                'Publish-AppeaseTaskTemplate',
                                'Install-AppeaseTaskTemplate',
                                'Uninstall-AppeaseTaskTemplate')
