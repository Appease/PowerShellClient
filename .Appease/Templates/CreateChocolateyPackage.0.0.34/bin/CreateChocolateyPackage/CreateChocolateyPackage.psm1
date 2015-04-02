# halt immediately on any errors which occur in this module
$ErrorActionPreference = "Stop"

function Invoke(

[String]
[ValidateNotNullOrEmpty()]
[Parameter(
    Mandatory=$true,
    ValueFromPipelineByPropertyName=$true)]
$AppeaseProjectRootDirPath,

[String[]]
[ValidateCount(1,[Int]::MaxValue)]
[Parameter(
    ValueFromPipelineByPropertyName = $true)]
$IncludeNuspecPath = @(gci -Path $AppeaseProjectRootDirPath -File -Filter '*.nuspec' -Recurse | %{$_.FullName}),

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
    ValueFromPipelineByPropertyName = $true)]
$Version){

    $NuspecFilePaths = gci -Path $IncludeNuspecPath -Filter '*.nuspec' -File -Exclude $ExcludeNuspecNameLike -Recurse:$Recurse | ?{!$_.PSIsContainer} | %{$_.FullName}

Write-Debug `
@"
`Located .nuspec's:
$($NuspecFilePaths | Out-String)
"@

    $initialLocation = Get-Location
    $ChocolateyCommand = 'chocolatey'
    Try{
        foreach($nuspecFilePath in $NuspecFilePaths)
        {
            Set-Location (Split-Path $nuspecFilePath -Parent)

            $ChocolateyParameters = @('pack',$nuspecFilePath)
        
            if($Version){
                $ChocolateyParameters += @('--version',$Version)
            }

Write-Debug `
@"
Invoking choco:
& $ChocolateyCommand $($ChocolateyParameters|Out-String)
"@
            & $ChocolateyCommand $ChocolateyParameters

            # handle errors
            if ($LastExitCode -ne 0) {
                throw $Error
            }
        }
    }
    Finally{
        Set-Location $initialLocation
    }
}

Export-ModuleMember -Function Invoke
