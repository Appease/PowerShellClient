Import-Module "$PSScriptRoot\..\Posh-CI-NuGet" -Force

function Get-SlnFile(
[string]$PathToParentDirectory,
[switch]$Recurse){    
    return Get-ChildItem $PathToParentDirectory -Recurse:$Recurse -Filter "*.sln" | %{$_.FullName}
}

function Invoke(
[string]$PathToParentDirectory,
[string]$PathToMsBuildExe,
[switch]$Recurse){

    $slnFiles = Get-SlnFile -PathToParentDirectory $PathToParentDirectory -Recurse:$Recurse

    if($slnFiles){
        foreach($slnFile in $slnFiles){

            # restore packages
            Posh-CI-NuGet\Invoke-Restore -SlnOrConfigFile $slnFile

            # invoke msbuild
            & $PathToMsBuildExe $slnFile

            # handle errors
            if ($LastExitCode -ne 0) {
                throw $Error
            }
        }
    }
    else{
        Write-Debug "no .sln files found"        
    }
}

Export-ModuleMember -Function Invoke
