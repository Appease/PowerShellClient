# installer based on guidelines provided by Microsoft 
# for installing shared/3rd party powershell modules
# (see: https://msdn.microsoft.com/en-us/library/dd878350%28v=vs.85%29.aspx )
if($PSVersionTable.PSVersion.Major -lt 3) {
    Write-Warning "PoshDevOps requires PowerShell 3.0 or better; you have version $($Host.Version)."
    return
}

# prepare install dir
$installRootDirPath = "$env:ProgramFiles\PoshDevOps"
$installDirPath = "$installRootDirPath\Modules"

# handle upgrade scenario
if(Test-Path "$installRootDirPath"){
    Write-Debug 'removing previous PoshDevOps installation'
    . "$PSScriptRoot\Uninstall.ps1"
}
New-Item $installDirPath -ItemType Directory | Out-Null

Copy-Item -Path "$PSScriptRoot" -Destination $installDirPath -Recurse

$psModulePath = [Environment]::GetEnvironmentVariable('PSModulePath','Machine')

# if installation dir path is not already in path then add it.
if(!($psModulePath.Split(';').Contains($installDirPath))){
    Write-Debug "adding $installDirPath to '$env:PSModulePath'"
    
    # trim trailing semicolon if exists
    $psModulePath = $psModulePath.TrimEnd(';');

    # append path to PoshDevOps installation
    $psModulePath = $psModulePath + ";$installDirPath"
    
    # save
    [Environment]::SetEnvironmentVariable('PSModulePath',$psModulePath,'Machine')    
    
    # make effective in current session
    $env:PSModulePath = $env:PSModulePath + ";$installDirPath"
}
