$installRootDirPath = "C:\Program Files\Appease"
$installDirPath = "$installRootDirPath\PowerShell"

# make idempotent
if(Test-Path $installDirPath){
    Remove-Item $installDirPath -Force -Recurse
}

# if this was the last module in $installDirPath remove from $env:PSModulePath
if(gci $installDirPath -Directory){
    # remove $PSModulePath modification
    $psModulePath = [Environment]::GetEnvironmentVariable('PSModulePath','Machine')

    $newPSModulePathParts = @();
    $isPSModulePathModified = $false
    foreach($part in $psModulePath.Split(';')){
        if($part -eq $installDirPath){
            $isPSModulePathModified = $true
        }
        else{
            $newPSModulePathParts += $part;        
        }
    }

    $psModulePath = $newPSModulePathParts -join ';'

    if($isPSModulePathModified){
        Write-Debug "updating '$env:PSModulePath' to $psModulePath"

        # save
        [Environment]::SetEnvironmentVariable('PSModulePath',$psModulePath,'Machine')
    }
}
