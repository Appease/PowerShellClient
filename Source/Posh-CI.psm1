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

function Get-CIStepsDirPath(
[string][Parameter(Mandatory=$true)]$ProjectRootDirPath){    

    "$(Get-CIPlanDirPath $ProjectRootDirPath)\Steps"

}

function ConvertTo-CIPlanJson(
[PSCustomObject][Parameter(Mandatory=$true)]$CIPlan){
    <#
        .SUMMARY
        an internal utility function to convert a runtime CIPlan object to a 
        JSON formatted string
    #>

    $stepsArray = $CIPlan.Steps.Values
    return ConvertTo-Json -InputObject ([PSCustomObject]@{"Steps"=$stepsArray}) -Depth 6

}

function ConvertFrom-CIPlanJson(
[string]$CIPlanFileContent){
    <#
        .SUMMARY
        an internal utility function to convert a JSON formatted string 
        into a runtime CIPlan object.
    #>

    $ciPlan = $CIPlanFileContent -join "`n" | ConvertFrom-Json

    # JSON doesnt support equivalent of PowerShell ordered dictionary so we must construct one
    # from an array(maintains order)
    $stepsArray = $ciPlan.Steps
    # steps must be ordered
    $stepsOrderedDictionary = [ordered]@{}
    $stepsArray | %{$stepsOrderedDictionary.Add($_.Name,$_)}
    
    return [pscustomobject]@{"Steps"=$stepsOrderedDictionary}    
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

function Save-CIPlan(
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

function Add-CIStep(
[string][Parameter(Mandatory=$true)]$Name,
[string]$ProjectRootDirPath = $PWD){
    $CIStepsDirPath = Get-CIStepsDirPath $ProjectRootDirPath
    $CIStepDirPath = "$CIStepsDirPath\$Name"
    $templatesDirPath = "$PSScriptRoot\Templates"
    
    if(!(Test-Path $CIStepDirPath)){
        
        # add the step to the plan
        $ciPlan = Get-CIPlan -ProjectRootDirPath $ProjectRootDirPath
        $ciPlan.Steps.Add($Name, [pscustomobject]@{Name=$Name})
        Save-CIPlan -CIPlan $ciPlan -ProjectRootDirPath $ProjectRootDirPath

        # add a powershell module
        New-Item -Path $CIStepDirPath -ItemType Directory
        Copy-Item -Path "$templatesDirPath\CIStep.psm1" "$CIStepDirPath\$Name.psm1"
        
    }
    else{
        throw "$Name directory already exists at $CIStepDirPath. If you are trying to recreate your $Name ci step from scratch you must invoke Remove-CIStep first"
    }
}


function Remove-CIStep(
[string][Parameter(Mandatory=$true)]$Name,
[switch]$Force,
[string]$ProjectRootDirPath = $PWD){

    $ciPlanDirPath = Get-CIPlanDirPath $ProjectRootDirPath
    $ciPlanFilePath = "$ciPlanDirPath\CIPlan.json"
    $CIStepsDirPath = Get-CIStepsDirPath $ProjectRootDirPath
    $CIStepDirPath = "$CIStepsDirPath\$Name"

    $confirmationPromptQuery = "Are you sure you want to delete the CI step located at $CIStepDirPath`?"
    $confirmationPromptCaption = 'Confirm ci step removal'

    if($Force.IsPresent -or $PSCmdlet.ShouldContinue($confirmationPromptQuery,$confirmationPromptCaption)){
        # remove the powershell module
        Remove-Item -Path $CIStepDirPath -Recurse -Force

        # remove the step from the plan
        $ciPlan = Get-CIPlan -ProjectRootDirPath $ProjectRootDirPath
        $ciPlan.Steps.Remove($Name)
        Save-CIPlan -CIPlan $ciPlan -ProjectRootDirPath $ProjectRootDirPath
    }
}

function New-CIPlan(
[string]$ProjectRootDirPath= $PWD){
    $ciPlanDirPath = Get-CIPlanDirPath $ProjectRootDirPath  

    if(!(Test-Path $ciPlanDirPath)){    
        $templatesDirPath = "$PSScriptRoot\Templates"
        $CIStepsDirPath = Get-CIStepsDirPath $ProjectRootDirPath

        # create a directory for the plan
        New-Item -ItemType Directory -Path $ciPlanDirPath

        # create a directory for the plans Steps
        New-Item -ItemType Directory -Path $CIStepsDirPath  

        # create default files
        Copy-Item -Path "$templatesDirPath\CIPlan.json" $ciPlanDirPath
        Copy-Item -Path "$templatesDirPath\Packages.config" $ciPlanDirPath
    }
    else{        
        throw "CIPlan directory already exists at $ciPlanDirPath. If you are trying to recreate your ci plan from scratch you must invoke Remove-CIPlan first"
    }
}

function Remove-CIPlan(
[switch]$Force,
[string]$ProjectRootDirPath= $PWD){
    
    $ciPlanDirPath = Get-CIPlanDirPath $ProjectRootDirPath

    $confirmationPromptQuery = "Are you sure you want to delete the CI plan located at $CIPlanDirPath`?"
    $confirmationPromptCaption = 'Confirm ci plan removal'

    if($Force.IsPresent -or $PSCmdlet.ShouldContinue($confirmationPromptQuery,$confirmationPromptCaption)){
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
        
        # clone step names before adding helper steps
        $stepNames = @()
        $CIPlan.Steps.Keys | %{$stepNames+=$_}

        foreach($stepName in $stepNames){
            
            # add/update "Current" step helper
            $CIPlan.Steps["Current"] = $CIPlan.Steps[$stepName]
            
            $stepDirPath = "$ciPlanDirPath\Steps\$($stepName)"
            Import-Module $stepDirPath -Force

            & "$($stepName)\Start-CIStep" -CIPlan $CIPlan
        }
    }
    else{
        throw "CIPlan.json not found at: $ciPlanFilePath"
    }
}

Export-ModuleMember -Function Invoke-CIPlan,New-CIPlan,Remove-CIPlan,Add-CIStep,Remove-CIStep