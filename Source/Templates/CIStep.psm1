# halt immediately on any errors which occur in this module
$ErrorActionPreference = "Stop"

function Start-CIStep(
[PSCustomObject]$CIPlan){
    #define your ci step here!
    Write-Host "Running $($CIPlan.Steps['Current'].Name) step!"
}

Export-ModuleMember Start-CIStep