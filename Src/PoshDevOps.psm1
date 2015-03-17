Write-Debug "Dot Sourcing $PSScriptRoot\PsonConverters.ps1"
. "$PSScriptRoot\PsonConverters.ps1"

$defaultPackageSources = @('https://www.myget.org/F/poshci')

function EnsureNuGetInstalled(){
    try{
        Get-Command nuget -ErrorAction Stop | Out-Null
    }
    catch{
Write-Debug "installing nuget.commandline"
        chocolatey install nuget.commandline | Out-Null
    }
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

    $ciPlanFilePath = Resolve-Path "$ProjectRootDirPath\.PoshDevOps\CIPlanArchive.psd1"   
Write-Output (Get-Content $ciPlanFilePath | Out-String | ConvertFrom-Pson)

}

function Save-CIPlan(
[PsCustomObject]
$CIPlan,

[string]
[Parameter(
    ValueFromPipeline=$true,
    ValueFromPipelineByPropertyName=$true)]
$ProjectRootDirPath = '.'){
    <#
        .SYNOPSIS
        an internal utility function to save a runtime CIPlan object as 
        a ci plan archive.
    #>
    
    $ciPlanFilePath = Resolve-Path "$ProjectRootDirPath\.PoshDevOps\CIPlanArchive.psd1"    
    Set-Content $ciPlanFilePath -Value (ConvertTo-Pson -InputObject $CIPlan -Depth 12 -Layers 12 -Strict)
}

function Get-UnionOfHashtables(
[Hashtable]
[ValidateNotNull()]
[Parameter(
    ValueFromPipeline=$true,
    ValueFromPipelineByPropertyName=$true)]
$Source1,

[Hashtable]
[ValidateNotNull()]
[Parameter(
    ValueFromPipeline=$true,
    ValueFromPipelineByPropertyName=$true)]
$Source2){
    $destination = $Source1.Clone()
    Write-Debug "After adding `$Source1, destination is $($destination|Out-String)"

    $Source2.GetEnumerator() | ?{!$destination.ContainsKey($_.Key)} |%{$destination[$_.Key] = $_.Value}
    Write-Debug "After adding `$Source2, destination is $($destination|Out-String)"

    Write-Output $destination
}

function Get-IndexOfKeyInOrderedDictionary(
[string]
[ValidateNotNullOrEmpty()]
$Key,

[System.Collections.Specialized.OrderedDictionary]
[ValidateNotNullOrEmpty()]
$OrderedDictionary){
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

function Get-LatestPackageVersion(
[string[]]
[Parameter(
    Mandatory=$true)]
$PackageSources = $defaultPackageSources,


[string]
[ValidateNotNullOrEmpty()]
[Parameter(
    Mandatory=$true)]
$PackageId){
    
    $versions = @()

    foreach($packageSource in $PackageSources){
        $uri = "$packageSource/api/v2/package-versions/$PackageId"
Write-Debug "Attempting to fetch package versions:` uri: $uri "
        $versions = $versions + (Invoke-RestMethod -Uri $uri)
Write-Debug "response from $uri was: ` $versions"
    }
    if(!$versions -or ($versions.Count -lt 1)){
throw "no versions of $PackageId could be located.` searched: $PackageSources"
    }

Write-Output ([Array]($versions| Sort-Object -Descending))[0]
}

function Add-PoshDevOpsTask(
[CmdletBinding(
    DefaultParameterSetName="add-PoshDevOpsTaskLast")]

[string]
[ValidateNotNullOrEmpty()]
[Parameter(
    Mandatory=$true)]
$Name,

[string]
[Parameter(
    Mandatory=$true)]
$PackageId,

[string]
$PackageVersion,

[switch]
[Parameter(
    Mandatory=$true,
    ParameterSetName='add-PoshDevOpsTaskFirst')]
$First,

[switch]
[Parameter(
    ParameterSetName='add-PoshDevOpsTaskLast')]
$Last,

[string]
[Parameter(
    Mandatory=$true,
    ParameterSetName='add-PoshDevOpsTaskAfter')]
$After,

[string]
[Parameter(
    Mandatory=$true,
    ParameterSetName='add-PoshDevOpsTaskBefore')]
$Before,

[string[]]
$PackageSources=$defaultPackageSources,

[string]
[Parameter(
    ValueFromPipeline=$true,
    ValueFromPipelineByPropertyName=$true)]
$ProjectRootDirPath = '.'){

    <#
        .SYNOPSIS
        Adds a new ci step to a ci plan
        
        .EXAMPLE
        Add-PoshDevOpsTask -Name "LastStep" -PackageId "poshci.git" -PackageVersion "0.0.3"
        
        Description:

        This command adds a new ci step (named LastStep) after all existing ci steps

        .EXAMPLE
        Add-PoshDevOpsTask -Name "FirstStep" -PackageId "poshci.git" -First

        Description:

        This command adds a new ci step (named FirstStep) before all existing ci steps

        .EXAMPLE
        Add-PoshDevOpsTask -Name "AfterSecondStep" -PackageId "poshci.git" -After "SecondStep"

        Description:

        This command adds a new ci step (named AfterSecondStep) after the existing ci step named SecondStep

        .EXAMPLE
        Add-PoshDevOpsTask -Name "BeforeSecondStep" -PackageId "poshci.git" -Before "SecondStep"

        Description:

        This command adds a new ci step (named BeforeSecondStep) before the existing ci step named SecondStep

    #>

    $ciPlan = Get-CIPlan -ProjectRootDirPath $ProjectRootDirPath
    
    if($ciPlan.Steps.Contains($Name)){

throw "A ci step with name $Name already exists.`n Tip: You can remove the existing step by invoking Remove-PoshDevOpsTask"
            
    }
    else{
        
        if([string]::IsNullOrWhiteSpace($PackageVersion)){
            $PackageVersion = Get-LatestPackageVersion -PackageSources $PackageSources -PackageId $PackageId
Write-Debug "using greatest available module version : $PackageVersion"
        }


        $key = $Name
        $value = [PSCustomObject]@{'Name'=$Name;'PackageId'=$PackageId;'PackageVersion'=$PackageVersion}

        if($First.IsPresent){
        
            $ciPlan.Steps.Insert(0,$key,$value)
        
        }
        elseif('add-PoshDevOpsTaskAfter' -eq $PSCmdlet.ParameterSetName){

            $indexOfAfter = Get-IndexOfKeyInOrderedDictionary -Key $After -OrderedDictionary $ciPlan.Steps
            # ensure step with key $After exists
            if($indexOfAfter -lt 0){
                throw "A ci step with name $After could not be found."
            }
            $ciPlan.Steps.Insert($indexOfAfter + 1,$key,$value)
        
        }
        elseif('add-PoshDevOpsTaskBefore' -eq $PSCmdlet.ParameterSetName){        
        
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

function Set-PoshDevOpsTaskParameters(

[string]
[ValidateNotNullOrEmpty()]
[Parameter(
    Mandatory=$true)]
$PoshDevOpsTaskName,

[hashtable]
[Parameter(
    Mandatory=$true)]
$Parameters,

[switch]$Force,

[string]
[Parameter(
    ValueFromPipeline=$true,
    ValueFromPipelineByPropertyName=$true)]
$ProjectRootDirPath = '.'){
    <#
        .SYNOPSIS
        Sets configurable parameters of a ci step
        
        .EXAMPLE
        Set-PoshDevOpsTaskParameters -PoshDevOpsTaskName "GitClone" -Parameters @{GitParameters=@("status")} -Force
        
        Description:

        This command sets a parameter (named "GitParameters") for a ci step (named "GitClone") to @("status")
    #>

    $ciPlan = Get-CIPlan -ProjectRootDirPath $ProjectRootDirPath
    $ciStep = $ciPlan.Steps.$PoshDevOpsTaskName
    $parametersPropertyName = "Parameters"

Write-Debug "Checking ci step `"$PoshDevOpsTaskName`" for property `"$parametersPropertyName`""
    $parametersPropertyValue = $ciStep.$parametersPropertyName    
    if($parametersPropertyValue){
        foreach($parameter in $Parameters.GetEnumerator()){

            $parameterName = $parameter.Key
            $parameterValue = $parameter.Value

Write-Debug "Checking if parameter `"$parameterName`" previously set"
            $previousParameterValue = $parametersPropertyValue.$parameterName
            if($previousParameterValue){
Write-Debug "Found parameter `"$parameterName`" previously set to `"$($previousParameterValue|Out-String)`""
$confirmationPromptQuery = 
@"
For ci step `"$PoshDevOpsTaskName`",
are you sure you want to change the value of parameter `"$parameterName`"?
    old value: $($previousParameterValue|Out-String)
    new value: $($parameterValue|Out-String)
"@

                $confirmationPromptCaption = "Confirm parameter value change"

                if($Force.IsPresent -or !$PSCmdlet.ShouldContinue($confirmationPromptQuery,$confirmationPromptCaption)){
Write-Debug "Skipping parameter `"$parameterName`". Overwriting existing parameter value was not confirmed."
                    continue
                }
            }
Write-Debug "Setting parameter `"$parameterName`" = `"$($parameterValue|Out-String)`" "
            $parametersPropertyValue.$parameterName = $parameterValue
        }
    }
    else {        
Write-Debug `
@"
Property `"$parametersPropertyName`" has not previously been set for ci step `"$PoshDevOpsTaskName`"
Adding with value:
$($Parameters|Out-String)
"@
        Add-Member -InputObject $ciStep -MemberType 'NoteProperty' -Name $parametersPropertyName -Value $Parameters -Force
    }
    
    Save-CIPlan -CIPlan $ciPlan -ProjectRootDirPath $ProjectRootDirPath
}

function Remove-PoshDevOpsTask(
[string]
[ValidateNotNullOrEmpty()]
[Parameter(
    Mandatory=$true)]
$Name,

[switch]$Force,

[string]
[Parameter(
    ValueFromPipeline=$true,
    ValueFromPipelineByPropertyName=$true)]
$ProjectRootDirPath = '.'){

    $confirmationPromptQuery = "Are you sure you want to delete the CI step with name $Name`?"
    $confirmationPromptCaption = 'Confirm ci step removal'

    if($Force.IsPresent -or $PSCmdlet.ShouldContinue($confirmationPromptQuery,$confirmationPromptCaption)){

        $ciPlan = Get-CIPlan -ProjectRootDirPath $ProjectRootDirPath
Write-Debug "Removing ci step $Name"
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
    $ciPlanDirPath = "$(Resolve-Path $ProjectRootDirPath)\.PoshDevOps"

    if(!(Test-Path $ciPlanDirPath)){    
        $templatesDirPath = "$PSScriptRoot\Templates"

Write-Debug "Creating a directory for the ci plan at path $ciPlanDirPath"
        New-Item -ItemType Directory -Path $ciPlanDirPath

Write-Debug "Adding default files to path $ciPlanDirPath"
        Copy-Item -Path "$templatesDirPath\CIPlanArchive.psd1" $ciPlanDirPath
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
    
    $ciPlanDirPath = Resolve-Path "$ProjectRootDirPath\.PoshDevOps"

    $confirmationPromptQuery = "Are you sure you want to delete the CI plan located at $CIPlanDirPath`?"
    $confirmationPromptCaption = 'Confirm ci plan removal'

    if($Force.IsPresent -or $PSCmdlet.ShouldContinue($confirmationPromptQuery,$confirmationPromptCaption)){
        Remove-Item -Path $ciPlanDirPath -Recurse -Force
    }
}

function Invoke-CIPlan(

[Hashtable]
[Parameter(
    ValueFromPipeline=$true,
    ValueFromPipelineByPropertyName=$true)]
$Parameters,

[string[]]
[Parameter(
    ValueFromPipelineByPropertyName=$true)]
$PackageSources = $defaultPackageSources,

[String]
[Parameter(
    ValueFromPipelineByPropertyName=$true)]
$ProjectRootDirPath='.'){
    
    $ciPlanDirPath = Resolve-Path "$ProjectRootDirPath\.PoshDevOps"
    $ciPlanFilePath = "$ciPlanDirPath\CIPlanArchive.psd1"
    $packagesDirPath = "$ciPlanDirPath\Packages"

    if(Test-Path $ciPlanFilePath){

        EnsureNuGetInstalled

        $CIPlan = Get-CIPlan -ProjectRootDirPath $ProjectRootDirPath

        foreach($step in $CIPlan.Steps.Values){
                    
            if($Parameters.($step.Name)){

                if($step.Parameters){

Write-Debug "Adding union of passed parameters and archived parameters to pipeline. Passed parameters will override archived parameters"
                
                    $stepParameters = Get-UnionOfHashtables -Source1 $Parameters.($step.Name) -Source2 $step.Parameters

                }
                else{

Write-Debug "Adding passed parameters to pipeline"

                    $stepParameters = $Parameters.($step.Name)
            
                }

            }
            elseif($step.Parameters){

Write-Debug "Adding archived parameters to pipeline"    
                $stepParameters = $step.Parameters

            }
            else{
                
                $stepParameters = @{}
            
            }

Write-Debug "Adding automatic parameters to pipeline"
            
            $stepParameters.PoshDevOpsProjectRootDirPath = (Resolve-Path $ProjectRootDirPath)
            $stepParameters.PoshDevOpsStepName = $step.Name

Write-Debug "Ensuring ci-step module package installed"
            nuget install $step.PackageId -Version $step.PackageVersion -OutputDirectory $packagesDirPath -Source $PackageSources -NonInteractive

            $moduleDirPath = "$packagesDirPath\$($step.PackageId).$($step.PackageVersion)\tools\$($step.PackageId)"
Write-Debug "Importing module located at: $moduleDirPath"
            Import-Module $moduleDirPath -Force

Write-Debug `
@"
Invoking ci-step $($step.Name) with parameters: 
$($stepParameters|Out-String)
"@
            # Parameters must be PSCustomObject so [Parameter(ValueFromPipelineByPropertyName = $true)] works
            [PSCustomObject]$stepParameters.Clone() | Invoke-PoshDevOpsTask

        }
    }
    else{

throw "CIPlanArchive.psd1 not found at: $ciPlanFilePath"

    }
}

Export-ModuleMember -Function Invoke-CIPlan,New-CIPlan,Remove-CIPlan,Add-PoshDevOpsTask,Set-PoshDevOpsTaskParameters,Remove-PoshDevOpsTask,Get-CIPlan
