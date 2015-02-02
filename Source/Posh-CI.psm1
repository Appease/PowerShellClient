function EnsureChocolateyInstalled(){
    # install chocolatey
    try{
        Get-Command choco -ErrorAction Stop | Out-Null
    }
    catch{             
        iex ((new-object net.webclient).DownloadString('https://chocolatey.org/install.ps1'))
    }
}

function Get-CIPlanDirPath(
[string][Parameter(Mandatory=$true)]$ProjectRootDirPath){
    "$ProjectRootDirPath\CIPlan"
}

function Get-CIStagesDirPath(
[string][Parameter(Mandatory=$true)]$ProjectRootDirPath){
    "$(Get-CIPlanDirPath $ProjectRootDirPath)\Stages"
}

function Add-CIStage(
[string][Parameter(Mandatory=$true)]$Name,
[string]$ProjectRootDirPath = $PWD){
    $ciStagesDirPath = Get-CIStagesDirPath $ProjectRootDirPath
    $ciStageDirPath = "$ciStagesDirPath\$Name"
    
    if(!(Test-Path $ciStageDirPath)){
        $ciPlanDirPath = Get-CIPlanDirPath $ProjectRootDirPath
        $ciPlanFilePath = "$ciPlanDirPath\CIPlan.json"

        # add the stage to the plan
        $ciPlan = (Get-Content $ciPlanFilePath) -join "`n" | ConvertFrom-Json
        $ciPlan.Stages += New-Object PSObject -Property @{Name=$Name}
        Set-Content $ciPlanFilePath -Value (ConvertTo-Json $ciPlan)

        # add a powershell module
        New-Item -Path $ciStageDirPath -ItemType Directory
        Copy-Item -Path "$templatesDirPath\CIStage.psm1" "$ciStageDirPath\$Name.psm1"
        
    }
    else{
        throw "$Name directory already exists at $ciStageDirPath. If you are trying to recreate your $Name ci stage from scratch you must invoke Remove-CIStage first"
    }
}

function Remove-CIStage(
[string][Parameter(Mandatory=$true)]$Name,
[string]$ProjectRootDirPath = $PWD){

    $ciPlanDirPath = Get-CIPlanDirPath $ProjectRootDirPath
    $ciPlanFilePath = "$ciPlanDirPath\CIPlan.json"
    $ciStagesDirPath = Get-CIStagesDirPath $ProjectRootDirPath
    $ciStageDirPath = "$ciStagesDirPath\$Name"
    $confirmation = Read-Host "Are you sure you want to delete the CI stage located at $ciStageDirPath`?`n type 'yes' proceeded by 'Enter' to confirm"
    
    if($confirmation -eq 'Yes'){
        # remove the powershell module
        Remove-Item -Path $ciStageDirPath -Recurse -Force

        # remove the stage from the plan
        $ciPlan = (Get-Content $ciPlanFilePath) -join "`n" | ConvertFrom-Json
        $ciPlan.Stages = ($ciPlan.Stages | Where-Object{!($_.Name -eq $Name)})
        Set-Content $ciPlanFilePath -Value (ConvertTo-Json $ciPlan)
    }
}

function New-CIPlan(
[string[]]$Stages,
[string]$ProjectRootDirPath= $PWD){
    $ciPlanDirPath = Get-CIPlanDirPath $ProjectRootDirPath  

    if(!(Test-Path $ciPlanDirPath)){    
        $templatesDirPath = "$PSScriptRoot\Templates"
        $ciStagesDirPath = Get-CIStagesDirPath $ProjectRootDirPath

        # create a directory for the plan
        New-Item -ItemType Directory -Path $ciPlanDirPath

        # create a directory for the plans Stages
        New-Item -ItemType Directory -Path $ciStagesDirPath  

        # create default files
        Copy-Item -Path "$templatesDirPath\CIPlan.json" $ciPlanDirPath
        Copy-Item -Path "$templatesDirPath\Packages.config" $ciPlanDirPath

        # add Stages
        foreach($stage in $Stages){
            Add-CIStage -Name $stage -ProjectRootDirPath $ProjectRootDirPath
        }
    }
    else{        
        throw "CIPlan directory already exists at $ciPlanDirPath. If you are trying to recreate your ci plan from scratch you must invoke Remove-CIPlan first"
    }
}

function Remove-CIPlan(
[string]$ProjectRootDirPath= $PWD){
    $ciPlanDirPath = Get-CIPlanDirPath $ProjectRootDirPath
    $confirmation = Read-Host "Are you sure you want to delete the CI plan located at $ProjectRoot`?`n type 'yes' proceeded by 'Enter' to confirm"
    if($confirmation -eq 'Yes'){
        Remove-Item -Path $ciPlanDirPath -Recurse -Force
    }
}

function Invoke-CIPlan(
[string]$ProjectRootDirPath= $PWD){
    
    $ciPlanDirPath = Get-CIPlanDirPath $ProjectRootDirPath
    $ciPlanFilePath = "$ciPlanDirPath\CIPlan.json"
    $packagesFilePath = "$ciPlanDirPath\Packages.config"
    if(Test-Path $ciPlanFilePath){
        EnsureChocolateyInstalled
        choco install $packagesFilePath

        # add variables to session
        $CIPlan = (Get-Content $ciPlanFilePath) -join "`n" | ConvertFrom-Json
        Add-Member -InputObject $CIPlan -MemberType CodeProperty -Name "Current"
        
        foreach($stage in $CIPlan.Stages){
            
            # update current stage variable
            $CIPlan.Stages.Current = $stage
            
            $stageDirPath = "$ciPlanDirPath\Stages\$($stage.Name)"
            Import-Module $stageDirPath -Force

            iex "$($stage.Name)\Start-CIStage"
        }
    }
    else{
        throw "CIPlan.json not found at: $ciPlanFilePath"
    }
}

Export-ModuleMember -Function Invoke-CIPlan,New-CIPlan,Remove-CIPlan,Add-CIStage,Remove-CIStage