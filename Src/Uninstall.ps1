$ModuleName = (gi $PSScriptRoot).Name
$RootInstallationDirPath = "C:\Program Files\Appease"
$RootPowerShellModuleInstallationDirPath = "$RootInstallationDirPath\PowerShell"
$ModuleInstallationDirPath = "$RootPowerShellModuleInstallationDirPath\$ModuleName"

# make idempotent
if(Test-Path $ModuleInstallationDirPath){
    Remove-Item -Path $ModuleInstallationDirPath -Recurse -Force
}

# make idempotent
if($RootInstallationDirPath -and !(gci $RootPowerShellModuleInstallationDirPath)){
    
    # remove $ModuleInstallationDirPath
    Remove-Item $RootPowerShellModuleInstallationDirPath -Force

    # remove $PSModulePath modification
    $PSModulePath = [Environment]::GetEnvironmentVariable('PSModulePath','Machine')

    $NewPSModulePathParts = @();
    $IsPSModulePathModified = $false
    foreach($part in $PSModulePath.Split(';')){
        if($part -eq $RootPowerShellModuleInstallationDirPath){
            $IsPSModulePathModified = $true
        }
        else{
            $NewPSModulePathParts += $part;        
        }
    }

    $PSModulePath = $NewPSModulePathParts -join ';'

    if($IsPSModulePathModified){
        Write-Debug "updating '$env:PSModulePath' to $PSModulePath"

        # save
        [Environment]::SetEnvironmentVariable('PSModulePath',$PSModulePath,'Machine')
    }
}

if(!(gci $RootInstallationDirPath)){
    
    Remove-Item $RootInstallationDirPath -Force
        
}