# halt immediately on any errors which occur in this module
$ErrorActionPreference = "Stop"

function Start-CIStep(
[String]$PoshCIHello){
    #define your ci step here!
    Write-Host $PoshCIHello
}

Export-ModuleMember Start-CIStep