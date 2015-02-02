function Start-CIStage(
){
    #add your stages tasks here!
    Write-Host "Running $($CIPlan.Stages['Current'].Name)"
}

Export-ModuleMember Start-CIStage