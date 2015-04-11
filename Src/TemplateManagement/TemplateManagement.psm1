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
$nuspecXmlString =
@"
<?xml version="1.0"?>
<package>
  <metadata>
    <id>$($TaskTemplateMetadata.$Id)</id>
    <version>$($TaskTemplateMetadata.$Version)</version>
    $(if($TaskTemplateMetadata.$Contributor){"<authors>$([string]::Join(',',($TaskTemplateMetadata.$Contributor|%{$_.Name})))</authors>"})
    $(if($TaskTemplateMetadata.$ProjectUrl){"<projectUrl>$($TaskTemplateMetadata.$ProjectUrl)</projectUrl>"})
    $(if($TaskTemplateMetadata.$IconUrl){"<iconUrl>$($TaskTemplateMetadata.$IconUrl)</iconUrl>"})
    <requireLicenseAcceptance>false</requireLicenseAcceptance>
    $(if($TaskTemplateMetadata.$Description){"<description>$($TaskTemplateMetadata.$Description)</description>"})
    $(if($TaskTemplateMetadata.$Tags){"<tags>$([string]::Join(" ",$TaskTemplateMetadata.$Tags))</tags>"})
  </metadata>
  <files>
    <file src="**" target="bin"/>
  </files>
</package>
"@
        $NuspecXml = [xml]($nuspecXmlString)

        Try
        {
            # generate a nuspec file
            $NuspecFilePath = Join-Path -Path $TaskTemplateDirPath -ChildPath "$([Guid]::NewGuid()).nuspec"
            New-Item -ItemType File -Path $NuspecFilePath -Force
            $NuspecXml.Save($(Resolve-Path $NuspecFilePath))

            # build a nupkg file
            New-NuGetPackage -NuspecFilePath $NuspecFilePath
            $NupkgFilePath = Join-Path -Path $TaskTemplateDirPath -ChildPath "$($TaskTemplateMetadata.$Id).$($TaskTemplateMetadata.$Version).nupkg"

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
    $TaskTemplateZipFilePath

){
    <#
        .SYNOPSIS
        an internal utility function that retrieves the metadata for a task template
    #>

    $TaskTemplateMetadataFilePath = "$TaskTemplateZipFilePath\metadata.json"

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
    
    [PSCustomObject[]]
    [ValidateCount(1,[int]::MaxValue)]
    [Parameter(
        Mandatory=$true,
        ValueFromPipelineByPropertyName = $true)]
    $SourceFilePathSpec,
    
    [string]
    [Parameter(
        ValueFromPipelineByPropertyName = $true)]
    $Description,
    
    [PSCustomObject[]]
    [Parameter(
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
    
    [string]
    [ValidateNotNullOrEmpty()]
    [Parameter(
        ValueFromPipelineByPropertyName = $true)]
    $DestinationDirPath

){
    
    $TaskTemplateDirPath = New-Item -Path "$DestinationDirPath\$Id.$Version" -ItemType Directory -Force

    # create metadata file 
     $TaskTemplateMetadataFilePath = "$TaskTemplateDirPath\metadata.json"
    New-Item -ItemType File -Path $TaskTemplateMetadataFilePath -Force
    $TaskTemplateMetadata = @{
        Id=$Id;
        Version=$Version;
        EntryPointType=$EntryPointType;
    }
    if($Description){
        $TaskTemplateMetadata.Description = $Description
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

    foreach($SourceFilePathSpecItem in $SourceFilePathSpecItem){
        Copy-Item @SourceFilePathSpecItem
    }

}

function Publish-AppeasePowerShellTaskTemplate(
    
    [string]    
    [ValidateNotNullOrEmpty()]
    [Parameter(
        Mandatory=$true,
        ValueFromPipelineByPropertyName = $true)]
    $Id,
    
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
        Mandatory=$true,
        ValueFromPipelineByPropertyName = $true)]
    $Version,
    
    [PSCustomObject[]]
    [Parameter(
        ValueFromPipelineByPropertyName = $true)]
    $Contributor,
    
    [PSCustomObject[]]
    [ValidateCount(1,[int]::MaxValue)]
    [Parameter(
        Mandatory=$true,
        ValueFromPipelineByPropertyName = $true)]
    $File,

    [PSCustomObject]
    [Parameter(
        ValueFromPipelineByPropertyName = $true)]
    $Dependencies,
    
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

    $TaskTemplateMetadataFileName = "$([Guid]::NewGuid()).json"
    
    # generate nuspec xml
$nuspecXmlString =
@"
<?xml version="1.0"?>
<package>
  <metadata>
    <id>$Id</id>
    <version>$Version</version>
    $(if($Contributor){"<authors>$([string]::Join(',',($Contributor|%{$_.Name})))</authors>"})
    $(if($ProjectUrl){"<projectUrl>$ProjectUrl</projectUrl>"})
    $(if($IconUrl){"<iconUrl>$IconUrl</iconUrl>"})
    <requireLicenseAcceptance>false</requireLicenseAcceptance>
    $(if($Description){"<description>$Description</description>"})
    $(if($Tags){"<tags>$([string]::Join(" ",$Tags))</tags>"})
  </metadata>
  <files>
    <file src="$TaskTemplateMetadataFileName" target="metadata.json"/>
    $([string]::Join([System.Environment]::NewLine,($File|%{"<file src=`"$([string]::Join(';',($_.Include)))`" target=`"bin\$($_.Destination)`" exclude=`"$([string]::Join(';',($TaskTemplateMetadataFileName + $_.Exclude)))`" />"})))
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

            # generate a metadata file
            $TaskTemplateMetadataFilePath = Join-Path -Path $ProjectRootDirPath -ChildPath $TaskTemplateMetadataFileName
            New-Item -ItemType File -Path $TaskTemplateMetadataFilePath -Force
            $TaskTemplateMetadata = @{}
            if($Dependencies){
                $TaskTemplateMetadata.Type = 'PowerShell'
                $TaskTemplateMetadata.Dependencies = $Dependencies
            }
            $TaskTemplateMetadata | ConvertTo-Json -Depth 12 | sc -Path $TaskTemplateMetadataFilePath -Force

            # build a nupkg file
            New-NuGetPackage -NuspecFilePath $NuspecFilePath
            $NuPkgFilePath = Join-Path -Path $ProjectRootDirPath -ChildPath "$Id.$Version.nupkg"

            # publish nupkg file
            Publish-NuGetPackage -NupkgFilePath $NuPkgFilePath -SourcePathOrUrl $DestinationPathOrUrl -ApiKey $ApiKey
            
        }
        Finally{
            Remove-Item $NuspecFilePath -Force
            Remove-Item $TaskTemplateMetadataFilePath -Force
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

    "$ProjectRootDirPath\.Appease\Templates\$Id.$Version" | Write-Output
    
}

function Get-AppeaseTaskTemplateMetadata(

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

    <#
        .SYNOPSIS
        Parses a dependencies.json file
    #>

    $TemplateInstallDirPath = Get-AppeaseTaskTemplateInstallDirPath -Id $Id -Version $Version -ProjectRootDirPath $ProjectRootDirPath
    $TemplateDependenciesFilePath = Join-Path -Path $TemplateInstallDirPath -ChildPath "\metadata.json"
    Get-Content $TemplateDependenciesFilePath | Out-String | ConvertFrom-Json | Write-Output

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

    $AppeaseTaskTemplateMetadata = Get-AppeaseTaskTemplateMetadata -Id $Id -Version $Version -ProjectRootDirPath $ProjectRootDirPath

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
                                'Get-AppeaseTaskTemplateInstallDirPath'
                                'Publish-AppeaseTaskTemplate',
                                'Install-AppeaseTaskTemplate',
                                'Uninstall-AppeaseTaskTemplate')
