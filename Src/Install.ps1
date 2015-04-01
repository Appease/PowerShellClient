# installer based on guidelines provided by Microsoft 
# for installing shared/3rd party powershell modules
# (see: https://msdn.microsoft.com/en-us/library/dd878350%28v=vs.85%29.aspx )

$ModuleName = (gi $PSScriptRoot).Name
if($PSVersionTable.PSVersion.Major -lt 3) {
    Write-Warning "$ModuleName requires PowerShell 3.0 or better; you have version $($Host.Version)."
    return
}

# prepare install dir
$RootInstallationDirPath = "$env:ProgramFiles\Appease"
$RootPowerShellModuleInstallationDirPath = "$RootInstallationDirPath\PowerShell"
$ModuleInstallationDirPath = "$RootPowerShellModuleInstallationDirPath\$ModuleName"

# handle upgrade scenario
if(Test-Path $ModuleInstallationDirPath){
    Write-Debug "removing previous $ModuleName installation"
    . "$PSScriptRoot\Uninstall.ps1"
}

if(!(Test-Path $RootPowerShellModuleInstallationDirPath)){
    New-Item $RootPowerShellModuleInstallationDirPath -ItemType Directory -Force | Out-Null
}

Copy-Item -Path $PSScriptRoot -Destination $RootPowerShellModuleInstallationDirPath -Recurse

$PSModulePath = [Environment]::GetEnvironmentVariable('PSModulePath','Machine')

# if $RootPowerShellModuleInstallationDirPath is not already in path then add it.
if(!($PSModulePath.Split(';').Contains($RootPowerShellModuleInstallationDirPath))){
    Write-Debug "adding $RootPowerShellModuleInstallationDirPath to '$env:PSModulePath'"
    
    # trim trailing semicolon if exists
    $PSModulePath = $PSModulePath.TrimEnd(';');

    # append path to Appease installation
    $PSModulePath += ";$RootPowerShellModuleInstallationDirPath"
    
    # save
    [Environment]::SetEnvironmentVariable('PSModulePath',$PSModulePath,'Machine')    
    
    # make effective in current session
    $env:PSModulePath = $env:PSModulePath + ";$RootPowerShellModuleInstallationDirPath"
}
