function Start-CIStage(
[PSCustomObject]$CIPlan){
    #add your stages tasks here!
    Write-Host "Running $($CIPlan.Stages["Current"].Name) stage!"
}

Export-ModuleMember Start-CIStage