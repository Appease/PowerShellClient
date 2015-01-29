# remove source
$installRootDirPath = "C:\Program Files\Posh-Grunt"
$installDirPath = "$installRootDirPath\Modules"

# make idempotent
if(Test-Path "$installRootDirPath"){
    Remove-Item $installRootDirPath -Force -Recurse
}

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
