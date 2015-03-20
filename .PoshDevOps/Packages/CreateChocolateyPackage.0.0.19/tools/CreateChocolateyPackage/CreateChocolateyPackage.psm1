# halt immediately on any errors which occur in this module
$ErrorActionPreference = "Stop"

function EnsureChocolateyInstalled(
[String]
[ValidateNotNullOrEmpty()]
$PathToChocolateyExe){
    # install chocolatey
    try{
        Get-Command $PathToChocolateyExe -ErrorAction Stop | Out-Null
    }
    catch{             
        iex ((new-object net.webclient).DownloadString('https://chocolatey.org/install.ps1'))
    }   
}

function Invoke-PoshDevOpsTask(

[String]
[ValidateNotNullOrEmpty()]
[Parameter(
    Mandatory=$true,
    ValueFromPipelineByPropertyName=$true)]
$PoshDevOpsProjectRootDirPath,

[String[]]
[ValidateCount(1,[Int]::MaxValue)]
[Parameter(
    ValueFromPipelineByPropertyName = $true)]
$IncludeNuspecPath = @(gci -Path $PoshDevOpsProjectRootDirPath -File -Filter '*.nuspec' -Recurse | %{$_.FullName}),

[String[]]
[Parameter(
    ValueFromPipelineByPropertyName = $true)]
$ExcludeNuspecNameLike,

[Switch]
[Parameter(
    ValueFromPipelineByPropertyName=$true)]
$Recurse,

[String]
[Parameter(
    ValueFromPipelineByPropertyName=$true)]
$OutputDirectoryPath,

[String]
[Parameter(
    ValueFromPipelineByPropertyName = $true)]
$Version,

[String]
[ValidateNotNullOrEmpty()]
[Parameter(
    ValueFromPipelineByPropertyName=$true)]
$PathToChocolateyExe = 'C:\ProgramData\chocolatey\bin\chocolatey.exe'){

    EnsureChocolateyInstalled -PathToChocolateyExe $PathToChocolateyExe

    $NuspecFilePaths = gci -Path $IncludeNuspecPath -Filter '*.nuspec' -File -Exclude $ExcludeNuspecNameLike -Recurse:$Recurse | ?{!$_.PSIsContainer} | %{$_.FullName}

Write-Debug `
@"
`Located .nuspec's:
$($NuspecFilePaths | Out-String)
"@

    if($OutputDirectoryPath){
        Push-Location ( Resolve-Path $OutputDirectoryPath)        
    }
    else{            
        Push-Location (Get-Location)       
    }

Write-Debug  `
@"
output directory is:
$OutputDirectoryPath
"@

    foreach($nuspecFilePath in $NuspecFilePaths)
    {
    
        $chocolateyParameters = @('pack',$nuspecFilePath)
        
        if($Version){
            $chocolateyParameters += @('-version',$Version)
        }

Write-Debug `
@"
Invoking choco:
& $PathToChocolateyExe $($chocolateyParameters|Out-String)
"@
        & $PathToChocolateyExe $chocolateyParameters

        # handle errors
        if ($LastExitCode -ne 0) {
            throw $Error
        }
    }

    # revert location
    Pop-Location
}

Export-ModuleMember -Function Invoke-PoshDevOpsTask 
