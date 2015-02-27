$defaultPackageSources = @('https://www.myget.org/F/posh-ci')

function EnsureNuGetInstalled(){
    try{
        Get-Command nuget -ErrorAction Stop | Out-Null
    }
    catch{
        Write-Debug "installing nuget.commandline"
        chocolatey install nuget.commandline | Out-Null
    }
}

function ConvertTo-CIPlanArchiveJson(
[PSCustomObject][Parameter(Mandatory=$true)]$CIPlan){
    <#
        .SYNOPSIS
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
        .SYNOPSIS
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
        .SYNOPSIS
        parses a ci plan archive and returns the archived ci plan
    #>

    $ciPlanFilePath = Resolve-Path "$ProjectRootDirPath\.posh-ci\CIPlanArchive.json"   
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
        .SYNOPSIS
        an internal utility function to save a runtime CIPlan object as 
        a CIPlan file.
    #>
    
    $ciPlanFilePath = Resolve-Path "$ProjectRootDirPath\.posh-ci\CIPlanArchive.json"    
    Set-Content $ciPlanFilePath -Value (ConvertTo-CIPlanArchiveJson -CIPlan $CIPlan)
}

function Get-IndexOfKeyInOrderedDictionary(
    [string]$Key,
    [System.Collections.Specialized.OrderedDictionary]$OrderedDictionary){
    <#
        .SYNOPSIS
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

function Get-LatestCIStepModuleVersion(
[Parameter(
    Mandatory=$true)]
[string[]]
$CIStepModuleSources,

[Parameter(
    Mandatory=$true)]
    [string]
$CIStepModuleId){
    
    $versions = @()

    foreach($ciStepModuleSource in $CIStepModuleSources){
        $uri = "$ciStepModuleSource/api/v2/package-versions/$CIStepModuleId"
        Write-Debug "Attempting to fetch ci-step module versions:` uri: $uri "
        $versions = $versions + (Invoke-RestMethod -Uri $uri)
        Write-Debug "response from $uri was: ` $versions"
    }
    if(!$versions -or ($versions.Count -lt 1)){
        throw "no versions of $CIStepModuleId could be located.` searched: $CIStepModuleSources"
    }

    Write-Output ($versions| Sort-Object -Descending)[0]
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
$ModulePackageId,

[string]
$ModulePackageVersion,

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

[string[]]
$CIStepModuleSources=$defaultPackageSources,

[string]
[Parameter(
    ValueFromPipeline=$true,
    ValueFromPipelineByPropertyName=$true)]
$ProjectRootDirPath = '.'){

    <#
        .SYNOPSIS
        Adds a new ci step to a ci plan using an explicit module package version
        
        .EXAMPLE
        Add-CIStep -Name "LastStep" -ModulePackageId "posh-ci-git" -ModulePackageVersion "0.0.3"
        
        Description:

        This command adds a new ci step (named LastStep) after all existing ci steps

        .EXAMPLE
        Add-CIStep -Name "FirstStep" -ModulePackageId "posh-ci-git" -First

        Description:

        This command adds a new ci step (named FirstStep) before all existing ci steps

        .EXAMPLE
        Add-CIStep -Name "AfterSecondStep" -ModulePackageId "posh-ci-git" -After "SecondStep"

        Description:

        This command adds a new ci step (named AfterSecondStep) after the existing ci step named SecondStep

        .EXAMPLE
        Add-CIStep -Name "BeforeSecondStep" -ModulePackageId "posh-ci-git" -Before "SecondStep"

        Description:

        This command adds a new ci step (named BeforeSecondStep) before the existing ci step named SecondStep

    #>

    $ciPlan = Get-CIPlan -ProjectRootDirPath $ProjectRootDirPath
    
    if($ciPlan.Steps.Contains($Name)){

        throw "A ci step with name $Name already exists.`n Tip: You can remove the existing step by invoking Remove-CIStep"
            
    }
    else{
        
        if([string]::IsNullOrWhiteSpace($ModulePackageVersion)){
            $ModulePackageVersion = Get-LatestCIStepModuleVersion -CIStepModuleSources $CIStepModuleSources -CIStepModuleId $ModulePackageId
            Write-Debug "using greatest available module version : $ModulePackageVersion"
        }


        $key = $Name
        $value = [PSCustomObject]@{'Name'=$Name;'ModulePackageId'=$ModulePackageId;'ModulePackageVersion'=$ModulePackageVersion}

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

        Write-Debug "saving ci plan"
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
    $ciPlanDirPath = "$(Resolve-Path $ProjectRootDirPath)\.posh-ci"

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
    
    $ciPlanDirPath = Resolve-Path "$ProjectRootDirPath\.posh-ci"

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

[string[]]
[Parameter(
    ValueFromPipelineByPropertyName=$true)]
$PackageSources = $defaultPackageSources,

[String]
[Parameter(
    ValueFromPipeline=$true,
    ValueFromPipelineByPropertyName=$true)]
$ProjectRootDirPath='.'){
    
    $ciPlanDirPath = Resolve-Path "$ProjectRootDirPath\.posh-ci"
    $ciPlanFilePath = "$ciPlanDirPath\CIPlanArchive.json"
    $packagesDirPath = "$ciPlanDirPath\Packages"

    if(Test-Path $ciPlanFilePath){

        EnsureNuGetInstalled        

        # add PoshCI plan lifetime variables to session
        Add-Member -InputObject $Variables -MemberType 'NoteProperty' -Name "PoshCIProjectRootDirPath" -Value (Resolve-Path $ProjectRootDirPath) -Force

        $CIPlan = Get-CIPlan -ProjectRootDirPath $ProjectRootDirPath

        foreach($step in $CIPlan.Steps.Values){

            Write-Debug "adding PoshCI step lifetime variables to session"
            Add-Member -InputObject $Variables -MemberType 'NoteProperty' -Name "PoshCIStepName" -Value $step.Name -Force

            Write-Debug "ensuring ci-step module package installed"
            nuget install $step.ModulePackageId -Version $step.ModulePackageVersion -OutputDirectory $packagesDirPath -Source $PackageSources -NonInteractive

            Write-Debug "importing module"
            Import-Module "$packagesDirPath\$($step.ModulePackageId).$($step.ModulePackageVersion)\tools\$($step.ModulePackageId)" -Force

            Write-Debug "invoking ci-step $($step.Name)"
            $Variables | Invoke-CIStep
        }
    }
    else{
        throw "CIPlanArchive.json not found at: $ciPlanFilePath"
    }
}

Export-ModuleMember -Function Invoke-CIPlan,New-CIPlan,Remove-CIPlan,Add-CIStep,Remove-CIStep,Get-CIPlan