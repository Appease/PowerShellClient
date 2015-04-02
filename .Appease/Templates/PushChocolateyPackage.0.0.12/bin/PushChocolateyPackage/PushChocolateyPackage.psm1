# halt immediately on any errors which occur in this module
$ErrorActionPreference = 'Stop'

function Invoke(

    [string[]]
    [ValidateCount(1,[Int]::MaxValue)]
    [Parameter(
        Mandatory=$true,
        ValueFromPipelineByPropertyName = $true)]
    $IncludeNupkgFilePath,

    [string[]]
    [Parameter(
        ValueFromPipelineByPropertyName = $true)]
    $ExcludeFileNameLike,

    [switch]
    [Parameter(
        ValueFromPipelineByPropertyName = $true)]
    $Recurse,

    [string]
    [Parameter(
        ValueFromPipelineByPropertyName = $true)]
    $SourceUrl = 'https://chocolatey.org/',

    [string]
    [Parameter(
        ValueFromPipelineByPropertyName = $true)]
    $ApiKey

){
    
    $NupkgFilePaths = gci -Path $IncludeNupkgFilePath -Filter '*.nupkg' -File -Exclude $ExcludeFileNameLike -Recurse:$Recurse | ?{!$_.PSIsContainer} | %{$_.FullName}
        
Write-Debug `
@"
`Located packages:
$($NupkgFilePaths | Out-String)
"@
    $ChocolateyCommand = 'chocolatey'

    foreach($nupkgFilePath in $NupkgFilePaths)
    {
        $ChocolateyParameters = @('push',$nupkgFilePath,'-Source',$SourceUrl)

        if($ApiKey){
            $ChocolateyParameters += @('-ApiKey',$ApiKey)
        }

Write-Debug `
@"
Invoking nuget:
$ChocolateyCommand $($ChocolateyParameters|Out-String)
"@
        & $ChocolateyCommand $ChocolateyParameters
        
        # handle errors
        if ($LastExitCode -ne 0) {
            throw $Error
        
        }

    }

}

Export-ModuleMember -Function Invoke
