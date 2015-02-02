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

function ConvertTo-CIPlanJson(
[PSCustomObject][Parameter(Mandatory=$true)]$CIPlan){

    $stagesArray = $CIPlan.Stages.Values
    return ConvertTo-Json -InputObject ([PSCustomObject]@{"Stages"=$stagesArray}) -Depth 6

}

function ConvertFrom-CIPlanJson(
[string]$CIPlanFileContent){

    $ciPlan = $CIPlanFileContent -join "`n" | ConvertFrom-Json

    # JSON doesnt support equivalent of PowerShell ordered dictionary so we must construct one
    # from an array(maintains order)
    $stagesArray = $ciPlan.Stages
    # stages must be ordered
    $stagesOrderedDictionary = [ordered]@{}
    $stagesArray | %{$stagesOrderedDictionary.Add($_.Name,$_)}
    
    return [pscustomobject]@{"Stages"=$stagesOrderedDictionary}    
}

function Get-CIPlan(
[string][Parameter(Mandatory=$true)]$ProjectRootDirPath){
    <#
        .SUMMARY
        an internal utility function to retrieve a CIPlan file and 
        instantiate a runtime CIPlan object.
    #>

    $ciPlanDirPath = "$ProjectRootDirPath\CIPlan"
    $ciPlanFilePath = "$ciPlanDirPath\CIPlan.json"
    return ConvertFrom-CIPlanJson -CIPlanFileContent (Get-Content $ciPlanFilePath)

}

function Set-CIPlan(
[psobject]$CIPlan,
[string][Parameter(Mandatory=$true)]$ProjectRootDirPath){
    <#
        .SUMMARY
        an internal utility function to save a runtime CIPlan object as 
        a CIPlan file.
    #>
    
    $ciPlanDirPath = "$ProjectRootDirPath\CIPlan"
    $ciPlanFilePath = "$ciPlanDirPath\CIPlan.json"    
    Set-Content $ciPlanFilePath -Value (ConvertTo-CIPlanJson -CIPlan $CIPlan)
}

function Add-CIStage(
[string][Parameter(Mandatory=$true)]$Name,
[string]$ProjectRootDirPath = $PWD){
    $ciStagesDirPath = Get-CIStagesDirPath $ProjectRootDirPath
    $ciStageDirPath = "$ciStagesDirPath\$Name"
    $templatesDirPath = "$PSScriptRoot\Templates"
    
    if(!(Test-Path $ciStageDirPath)){
        
        # add the stage to the plan
        $ciPlan = Get-CIPlan -ProjectRootDirPath $ProjectRootDirPath
        $ciPlan.Stages.Add($Name, [pscustomobject]@{Name=$Name})
        Set-CIPlan -CIPlan $ciPlan -ProjectRootDirPath $ProjectRootDirPath

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
        $ciPlan = Get-CIPlan -ProjectRootDirPath $ProjectRootDirPath
        $ciPlan.Stages.Remove($Name)
        Set-CIPlan -CIPlan $ciPlan -ProjectRootDirPath $ProjectRootDirPath
    }
}

function New-CIPlan(
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
        $CIPlan = Get-CIPlan -ProjectRootDirPath $ProjectRootDirPath
        
        # clone stage names before adding helper stages
        $stageNames = @()
        $CIPlan.Stages.Keys | %{$stageNames+=$_}

        foreach($stageName in $stageNames){
            
            # add/update "Current" stage helper
            $CIPlan.Stages["Current"] = $CIPlan.Stages[$stageName]
            
            $stageDirPath = "$ciPlanDirPath\Stages\$($stageName)"
            Import-Module $stageDirPath -Force

            & "$($stageName)\Start-CIStage" -CIPlan $CIPlan
        }
    }
    else{
        throw "CIPlan.json not found at: $ciPlanFilePath"
    }
}

Export-ModuleMember -Function Invoke-CIPlan,New-CIPlan,Remove-CIPlan,Add-CIStage,Remove-CIStage