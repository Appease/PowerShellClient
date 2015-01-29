function EnsureNuGetCommandLineInstalled(){
    # install nuget-commandline
    try{
        Get-Command nuget -ErrorAction Stop | Out-Null
    }
    catch{             
        cinst 'nuget.commandline'
    }    
}

function Get-NuspecFile(
[string]$PathToParentDirectory,
[switch]$Recurse){    
    return (Get-ChildItem $PathToParentDirectory -Filter '*.nuspec' -Recurse:$Recurse) | %{$_.FullName}
}

function Invoke-Restore(
[string]$SlnOrConfigFile){
    EnsureNuGetCommandLineInstalled
    nuget restore $SlnOrConfigFile
}

function Invoke-Pack(
[string]$PathToParentDirectory,
[string]$PathToBuildArtifactsDirectory,
[switch]$Recurse){
    EnsureNuGetCommandLineInstalled

    $nuspecFiles = Get-NuspecFile -PathToParentDirectory $PathToParentDirectory -Recurse:$Recurse
    
    if($nuspecFiles){
        foreach($nuspecFile in $nuspecFiles){
            
            # invoke nuget pack
            nuget pack ($nuspecFile -ireplace '.nuspec','.csproj') `
            -Symbols `
            -OutputDirectory $PathToBuildArtifactsDirectory

            # handle errors
            if ($LastExitCode -ne 0) {
                throw $Error
            }
        }
    }
    else{
        Write-Debug "no .nuspec files found"    
    }   
}

Export-ModuleMember -Function Invoke-Pack,Invoke-Restore
