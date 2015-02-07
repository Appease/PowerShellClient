function EnsureChocolateyInstalled(){

    # install chocolatey
    try{
        Get-Command choco -ErrorAction 'Stop' | Out-Null
    }
    catch{             
        iex ((new-object net.webclient).DownloadString('https://chocolatey.org/install.ps1'))
    }

}

function ConvertTo-CIPlanArchiveJson(
[PSCustomObject][Parameter(Mandatory=$true)]$CIPlan){
    <#
        .SUMMARY
        an internal utility function to convert a runtime CIPlan object to a 
        ci plan archive formatted as a json string
    #>

    # construct ci plan archive from ci plan
    $ciPlanArchiveSteps = @()
    $CIPlan.Steps.Values | %{$ciPlanArchiveSteps += $_}
    $ciPlanArchive = [PSCustomObject]@{'Steps'=$ciPlanArchiveSteps}

    Write-Output (ConvertTo-Json -InputObject $ciPlanArchive -Depth 4)

}

function ConvertFrom-CIPlanArchiveJson(
[string]$CIPlanFileContent){
    <#
        .SUMMARY
        an internal utility function to convert a ci plan archive formatted as a json string
        into a runtime CIPlan object.
    #>

    $ciPlanArchive = $CIPlanFileContent -join "`n" | ConvertFrom-Json

    # construct a ci plan from a ci plan archive
    $ciPlanSteps = [ordered]@{}
    $ciPlanArchive.Steps | %{$ciPlanSteps.Add($_.Name,$_)}
    
    Write-Output ([pscustomobject]@{'Steps'=$ciPlanSteps})

}

function Get-CIPlan(
[string]
[Parameter(
    ValueFromPipeline=$true,
    ValueFromPipelineByPropertyName=$true)]
$ProjectRootDirPath = '.'){
    <#
        .SUMMARY
        a utility function to parse a ci plan archive and 
        instantiate a runtime CIPlan object.
    #>

    $ciPlanFilePath = Resolve-Path "$ProjectRootDirPath\CIPlan\CIPlanArchive.json"   
    Write-Output (ConvertFrom-CIPlanArchiveJson -CIPlanFileContent (Get-Content $ciPlanFilePath))

}

function Save-CIPlan(
[psobject]$CIPlan,
[string]
[Parameter(
    ValueFromPipeline=$true,
    ValueFromPipelineByPropertyName=$true)]
$ProjectRootDirPath = '.'){
    <#
        .SUMMARY
        an internal utility function to save a runtime CIPlan object as 
        a CIPlan file.
    #>
    
    $ciPlanFilePath = Resolve-Path "$ProjectRootDirPath\CIPlan\CIPlanArchive.json"    
    Set-Content $ciPlanFilePath -Value (ConvertTo-CIPlanArchiveJson -CIPlan $CIPlan)
}

function Get-IndexOfKeyInOrderedDictionary(
    [string]$Key,
    [System.Collections.Specialized.OrderedDictionary]$OrderedDictionary){
    <#
        .SUMMARY
        an internal utility function to find the index of a key in an ordered dictionary
    #>
    $indexOfKey = -1
    $keysArray = [string[]]$OrderedDictionary.Keys
    for ($i = 0; $i -lt $OrderedDictionary.Count; $i++){
        if($keysArray[$i] -eq $Key){
            $indexOfKey = $i
            break
        }
    }

    Write-Output $indexOfKey
}

function Add-CIStep(
[CmdletBinding(
    DefaultParameterSetName="add-CIStepLast")]

[string]
[Parameter(
    Mandatory=$true)]
$Name,

[string]
[Parameter(
    Mandatory=$true)]
$ModulePath,

[switch]
[Parameter(
    Mandatory=$true,
    ParameterSetName='add-CIStepFirst')]
$First,

[switch]
[Parameter(
    ParameterSetName='add-CIStepLast')]
$Last,

[string]
[Parameter(
    Mandatory=$true,
    ParameterSetName='add-CIStepAfter')]
$After,

[string]
[Parameter(
    Mandatory=$true,
    ParameterSetName='add-CIStepBefore')]
$Before,

[string]
[Parameter(
    ValueFromPipeline=$true,
    ValueFromPipelineByPropertyName=$true)]
$ProjectRootDirPath = '.'){

    <#
        .SYNOPSIS
        Adds a new ci step to a ci plan
        
        .EXAMPLE
        Add-CIStep -Name "LastStep" -ModulePath "Some_Module_Path"
        
        Description:

        This command adds a new ci step (named LastStep) after all existing ci steps

        .EXAMPLE
        Add-CIStep -Name "FirstStep" -ModulePath "Some_Module_Path" -First

        Description:

        This command adds a new ci step (named FirstStep) before all existing ci steps

        .EXAMPLE
        Add-CIStep -Name "AfterSecondStep" -ModulePath "Some_Module_Path" -After "SecondStep"

        Description:

        This command adds a new ci step (named AfterSecondStep) after the existing ci step named SecondStep

        .EXAMPLE
        Add-CIStep -Name "BeforeSecondStep" -ModulePath "Some_Module_Path" -Before "SecondStep"

        Description:

        This command adds a new ci step (named BeforeSecondStep) before the existing ci step named SecondStep

    #>

    $ciPlan = Get-CIPlan -ProjectRootDirPath $ProjectRootDirPath
    
    if($ciPlan.Steps.Contains($Name)){

        throw "A ci step with name $Name already exists.`n Tip: You can remove the existing step by invoking Remove-CIStep"
            
    }
    else{

        $key = $Name
        $value = [PSCustomObject]@{'Name'=$Name;'ModulePath'=$ModulePath}

        if($First.IsPresent){
        
            $ciPlan.Steps.Insert(0,$key,$value)
        
        }
        elseif('add-CIStepAfter' -eq $PSCmdlet.ParameterSetName){

            $indexOfAfter = Get-IndexOfKeyInOrderedDictionary -Key $After -OrderedDictionary $ciPlan.Steps
            # ensure step with key $After exists
            if($indexOfAfter -lt 0){
                throw "A ci step with name $After could not be found."
            }
            $ciPlan.Steps.Insert($indexOfAfter + 1,$key,$value)
        
        }
        elseif('add-CIStepBefore' -eq $PSCmdlet.ParameterSetName){        
        
            $indexOfBefore = Get-IndexOfKeyInOrderedDictionary -Key $Before -OrderedDictionary $ciPlan.Steps
            # ensure step with key $Before exists
            if($indexOfBefore -lt 0){
                throw "A ci step with name $Before could not be found."
            }
            $ciPlan.Steps.Insert($indexOfBefore,$key,$value)
        
        }
        else{
        
            # by default add as last step
            $ciPlan.Steps.Add($key, $value)
        
        }

        Save-CIPlan -CIPlan $ciPlan -ProjectRootDirPath $ProjectRootDirPath    

    }
}

function Remove-CIStep(
[string][Parameter(Mandatory=$true)]$Name,
[switch]$Force,
[string]
[Parameter(
    ValueFromPipeline=$true,
    ValueFromPipelineByPropertyName=$true)]
$ProjectRootDirPath = '.'){

    $confirmationPromptQuery = "Are you sure you want to delete the CI step with name $Name`?"
    $confirmationPromptCaption = 'Confirm ci step removal'

    if($Force.IsPresent -or $PSCmdlet.ShouldContinue($confirmationPromptQuery,$confirmationPromptCaption)){

        # remove step from plan
        $ciPlan = Get-CIPlan -ProjectRootDirPath $ProjectRootDirPath
        $ciPlan.Steps.Remove($Name)
        Save-CIPlan -CIPlan $ciPlan -ProjectRootDirPath $ProjectRootDirPath
    }

}

function New-CIPlan(
[string]
[Parameter(
    ValueFromPipeline=$true,
    ValueFromPipelineByPropertyName=$true)]
$ProjectRootDirPath = '.'){
    $ciPlanDirPath = Resolve-Path "$ProjectRootDirPath\CIPlan"

    if(!(Test-Path $ciPlanDirPath)){    
        $templatesDirPath = "$PSScriptRoot\Templates"

        # create a directory for the plan
        New-Item -ItemType Directory -Path $ciPlanDirPath

        # create default files
        Copy-Item -Path "$templatesDirPath\CIPlanArchive.json" $ciPlanDirPath
        Copy-Item -Path "$templatesDirPath\Packages.config" $ciPlanDirPath
    }
    else{        
        throw "CIPlan directory already exists at $ciPlanDirPath. If you are trying to recreate your ci plan from scratch you must invoke Remove-CIPlan first"
    }
}

function Remove-CIPlan(
[switch]$Force,
[string]
[Parameter(
    ValueFromPipeline=$true,
    ValueFromPipelineByPropertyName=$true)]
$ProjectRootDirPath = '.'){
    
    $ciPlanDirPath = Resolve-Path "$ProjectRootDirPath\CIPlan"

    $confirmationPromptQuery = "Are you sure you want to delete the CI plan located at $CIPlanDirPath`?"
    $confirmationPromptCaption = 'Confirm ci plan removal'

    if($Force.IsPresent -or $PSCmdlet.ShouldContinue($confirmationPromptQuery,$confirmationPromptCaption)){
        Remove-Item -Path $ciPlanDirPath -Recurse -Force
    }
}

function Invoke-CIPlan(

[PSCustomObject]
[Parameter(
    ValueFromPipeline=$true,
    ValueFromPipelineByPropertyName=$true)]
$Variables=@{'PoshCIHello'="Hello from Posh-CI!"},

[String]
[Parameter(
    ValueFromPipeline=$true,
    ValueFromPipelineByPropertyName=$true)]
$ProjectRootDirPath='.'){
    
    $ciPlanDirPath = Resolve-Path "$ProjectRootDirPath\CIPlan"
    $ciPlanFilePath = "$ciPlanDirPath\CIPlanArchive.json"
    $packagesFilePath = "$ciPlanDirPath\Packages.config"
    if(Test-Path $ciPlanFilePath){
        EnsureChocolateyInstalled
        choco install $packagesFilePath

        # add variables to session
        $CIPlan = Get-CIPlan -ProjectRootDirPath $ProjectRootDirPath

        foreach($step in $CIPlan.Steps.Values){
            Import-Module (resolve-path $step.ModulePath) -Force
            $Variables | Invoke-CIStep
        }
    }
    else{
        throw "CIPlanArchive.json not found at: $ciPlanFilePath"
    }
}

Export-ModuleMember -Function Invoke-CIPlan,New-CIPlan,Remove-CIPlan,Add-CIStep,Remove-CIStep,Get-CIPlan