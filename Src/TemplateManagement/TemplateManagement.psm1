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

    $OutputDirectory = (gi $NuspecFilePath).DirectoryName
    
    $NugetParameters = @('pack',$NuspecFilePath,'-OutputDirectory',$OutputDirectory)

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

    if(Test-Path $SourcePathOrUrl -PathType Container){
        $SourcePathOrUrl = Resolve-Path $SourcePathOrUrl
    }

    $NuGetParameters = @('push',(Resolve-Path $NupkgFilePath),'-Source',$SourcePathOrUrl)

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

function Publish-AppeaseTaskTemplateToNupkgSource(

    [string]    
    [ValidateNotNullOrEmpty()]
    [Parameter(
        Mandatory=$true,
        ValueFromPipelineByPropertyName = $true)]
    $TaskTemplateDirPath,
    
    [string]
    [ValidateNotNullOrEmpty()]
    [Parameter(
        ValueFromPipelineByPropertyName = $true)]
    $DestinationPathOrUrl = $DefaultTemplateSources[0],

    [string]
    [Parameter(
        ValueFromPipelineByPropertyName = $true)]
    $ApiKey

){

    <#
        .SYNOPSIS
        an internal utility function that publishes a task template to a .nupkg source
    #>

    $TaskTemplateMetadata = Get-AppeaseTaskTemplateMetadata -TaskTemplateDirPath $TaskTemplateDirPath
    
    # generate nuspec xml
$NuspecXmlString =
@"
<?xml version="1.0"?>
<package>
  <metadata>
    <id>$($TaskTemplateMetadata.Id)</id>
    <version>$($TaskTemplateMetadata.Version)</version>
    <authors>$([string]::Join(',',($TaskTemplateMetadata.Maintainers|%{$_.Name})))</authors>
    $(if($TaskTemplateMetadata.ProjectUrl){"<projectUrl>$($TaskTemplateMetadata.ProjectUrl)</projectUrl>"})
    $(if($TaskTemplateMetadata.IconUrl){"<iconUrl>$($TaskTemplateMetadata.IconUrl)</iconUrl>"})
    <requireLicenseAcceptance>false</requireLicenseAcceptance>
    <description>$($TaskTemplateMetadata.Description)</description>
    $(if($TaskTemplateMetadata.Tags){"<tags>$([string]::Join(" ",$TaskTemplateMetadata.Tags))</tags>"})
  </metadata>
  <files>
    <file src="**" target=""/>
  </files>
</package>
"@
        $NuspecXml = [xml]($NuspecXmlString)

        Try
        {
            # generate a temp nuspec file
            $NuspecFilePath = Join-Path -Path $TaskTemplateDirPath -ChildPath "$([Guid]::NewGuid()).nuspec"
            New-Item -ItemType File -Path $NuspecFilePath -Force
            $NuspecXml.Save($(Resolve-Path $NuspecFilePath))

            # build a nupkg file
            New-NuGetPackage -NuspecFilePath $NuspecFilePath
            $NupkgFilePath = Join-Path -Path $TaskTemplateDirPath -ChildPath "$($TaskTemplateMetadata.Id).$($TaskTemplateMetadata.Version).nupkg"

            # publish nupkg file
            Publish-NuGetPackage -NupkgFilePath $NuPkgFilePath -SourcePathOrUrl $DestinationPathOrUrl -ApiKey $ApiKey
            
        }
        Finally{
            Remove-Item $NuspecFilePath -Force
            Remove-Item $NupkgFilePath -Force
        }
}

function Get-AppeaseTaskTemplateMetadata(

    [string]    
    [ValidateNotNullOrEmpty()]
    [Parameter(
        Mandatory=$true,
        ValueFromPipelineByPropertyName = $true)]
    $TaskTemplateDirPath

){
    <#
        .SYNOPSIS
        an internal utility function that retrieves the metadata for a task template
    #>

    $TaskTemplateMetadataFilePath = "$TaskTemplateDirPath\metadata.json"

    if(!(Test-Path $TaskTemplateMetadataFilePath)){
throw `
@"
task template metadata not found for task template
'$TaskTemplateMetadataFilePath'
"@
    }

    $TaskTemplateMetadata = Get-Content $TaskTemplateMetadataFilePath | Out-String | ConvertFrom-Json
    Write-Output $TaskTemplateMetadata
}

function Save-AppeaseTaskTemplate(

    [string]    
    [ValidateNotNullOrEmpty()]
    [Parameter(
        Mandatory=$true,
        ValueFromPipelineByPropertyName = $true)]
    $Id,
    
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
        Mandatory=$true,
        ValueFromPipelineByPropertyName = $true)]
    $Version,
    
    [string]
    [ValidateCount(1,[int]::MaxValue)]
    [Parameter(
        Mandatory=$true,
        ValueFromPipelineByPropertyName = $true)]
    $SourceDir,
    
    [string]
    [ValidateNotNullOrEmpty()]
    [Parameter(
        Mandatory=$true,
        ValueFromPipelineByPropertyName = $true)]
    $Description,
    
    [string]
    [ValidateSet('PowerShell3Module','PowerShell4Module')]
    [Parameter(
        ValueFromPipelineByPropertyName = $true)]
    $Type = 'PowerShell3Module',

    [string]
    [PSCustomObject[]]
    $Parameters,
    
    [PSCustomObject[]]
    [ValidateNotNullOrEmpty()]
    [Parameter(
        Mandatory=$true,
        ValueFromPipelineByPropertyName = $true)]
    $Maintainer,

    [PSCustomObject]
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
    $Tag,

    [switch]
    $Force,
    
    [string]
    [ValidateNotNullOrEmpty()]
    [Parameter(
        ValueFromPipelineByPropertyName = $true)]
    $DestinationDirPath = '.'

){
    
    $TaskTemplateDirPath = "$DestinationDirPath\$Id.$Version"
    If((Test-Path $TaskTemplateDirPath) -and !$Force.IsPresent){
        
throw `
@"
Task template already exists at:
'$TaskTemplateDirPath'
To overwrite existing task template include the -Force parameter
"@

    }
    Else{
        
        Remove-Item -Path $TaskTemplateDirPath -Recurse -Force

        New-Item -Path $TaskTemplateDirPath -ItemType Directory

        # create metadata file 
         $TaskTemplateMetadataFilePath = "$TaskTemplateDirPath\metadata.json"
        New-Item -ItemType File -Path $TaskTemplateMetadataFilePath -Force
        $TaskTemplateMetadata = @{
            Id=$Id;
            Version=$Version;
            Description=$Description;
            Type=$Type;
        }
        if($Parameters){
            $TaskTemplateMetadata.Parameters = $Parameters
        }
        if($Maintainer){
            $TaskTemplateMetadata.Maintainers = $Maintainer
        }
        if($Dependency){
            $TaskTemplateMetadata.Dependencies = $Dependencies
        }
        if($IconUrl){
            $TaskTemplateMetadata.IconUrl = $IconUrl
        }
        if($ProjectUrl){
            $TaskTemplateMetadata.ProjectUrl = $ProjectUrl
        }
        if($Tag){
            $TaskTemplateMetadata.Tags = $Tag
        }
        $TaskTemplateMetadata | ConvertTo-Json -Depth 12 | sc -Path $TaskTemplateMetadataFilePath -Force

        Copy-Item $SourceDir "$TaskTemplateDirPath\bin" -Recurse -Container -Force
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

    "$ProjectRootDirPath\.Appease\Templates\$Id.$Version" | Write-Output
    
}

function Install-NuGetPackage(

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
    [ValidateNotNullOrEmpty()]
    [Parameter(
        ValueFromPipelineByPropertyName=$true)]
    $OutputDirPath
){

    $InitialOFS = $OFS
    
    Try{

        $OFS = ';'        
        $NugetParameters = @('install',$Id,'-Source',($Source|Out-String),'-OutputDirectory',$OutputDirPath,'-Version',$Version,'-NonInteractive')

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
        $OFS = $InitialOFS
    }

}

function Install-ChocolateyPackage(

    [string]
    [ValidateNotNullOrEmpty()]
    [Parameter(
        Mandatory=$true,
        ValueFromPipelineByPropertyName=$true)]
    $Id,

    [string]
    [ValidateNotNullOrEmpty()]
    [Parameter(
        ValueFromPipelineByPropertyName=$true)]
    $Source,

    [string]
    [ValidateNotNullOrEmpty()]
    [Parameter(        
        ValueFromPipelineByPropertyName=$true)]
    $Version,

    [string]
    [Parameter(
        ValueFromPipelineByPropertyName=$true)]
    $InstallArguments,

    [switch]
    [Parameter(
        ValueFromPipelineByPropertyName=$true)]
    $OverrideArguments,

    [string]
    [Parameter(
        ValueFromPipelineByPropertyName=$true)]
    $PackageParameters,

    [switch]
    [Parameter(
        ValueFromPipelineByPropertyName=$true)]
    $AllowMultipleVersions,

    [switch]
    [Parameter(
        ValueFromPipelineByPropertyName=$true)]
    $IgnoreDependencies

){
    
    $ChocolateyParameters = @('install',$Id,'--confirm')

    if($Source){
        $ChocolateyParameters += @('--source',$Source)
    }

    if($Version){
        $ChocolateyParameters += @('--version',$Version)
    }

    if($InstallArguments){
        $ChocolateyParameters += @('--install-arguments',$InstallArguments)
    }
        
    if($OverrideArguments.IsPresent){
        $ChocolateyParameters += @('--override-arguments')
    }

    if($PackageParameters){
        $ChocolateyParameters += @('--package-parameters',$PackageParameters)
    }

    if($AllowMultipleVersions.IsPresent){
        $ChocolateyParameters += @('--allow-multiple-versions')
    }

    if($IgnoreDependencies.IsPresent){
        $IgnoreDependencies += @('--ignore-dependencies')
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

    if([string]::IsNullOrWhiteSpace($Version)){

        $Version = Get-LatestTemplateVersion -Source $Source -Id $Id

Write-Debug "using greatest available template version : $Version"
    
    }

    # install NuGet package containing task template
    Install-NuGetPackage -Id $Id -Version $Version -Source $Source -OutputDirPath "$ProjectRootDirPath\.Appease\Templates"

    $TaskTemplateDirPath = Get-AppeaseTaskTemplateInstallDirPath -Id $Id -Version $Version -ProjectRootDirPath $ProjectRootDirPath
    $AppeaseTaskTemplateMetadata = Get-AppeaseTaskTemplateMetadata -TaskTemplateDirPath $TaskTemplateDirPath

    # install Chocolatey dependencies
    $AppeaseTaskTemplateMetadata.Dependencies.Chocolatey | %{if($_){$_ | Install-ChocolateyPackage}}
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
                                'Get-AppeaseTaskTemplateInstallDirPath',
                                'Save-AppeaseTaskTemplate',
                                'Publish-AppeaseTaskTemplateToNupkgSource',
                                'Install-AppeaseTaskTemplate',
                                'Uninstall-AppeaseTaskTemplate')
