Write-Debug "Dot Sourcing $PSScriptRoot\PsonConverters.ps1"
. "$PSScriptRoot\PsonConverters.ps1"

$defaultPackageSources = @('https://www.myget.org/F/poshdevops')

function EnsureNuGetInstalled(){
    try{
        Get-Command nuget -ErrorAction Stop | Out-Null
    }
    catch{
Write-Debug "installing nuget.commandline"
        chocolatey install nuget.commandline | Out-Null
    }
}

function Get-DevOpsPlan(
[string]
[Parameter(
    ValueFromPipeline=$true,
    ValueFromPipelineByPropertyName=$true)]
$ProjectRootDirPath = '.'){
    <#
        .SYNOPSIS
        parses a DevOps plan file
    #>

    $devOpsPlanFilePath = Resolve-Path "$ProjectRootDirPath\.PoshDevOps\DevOpsPlan.psd1"   
Write-Output (Get-Content $devOpsPlanFilePath | Out-String | ConvertFrom-Pson)

}

function Save-DevOpsPlan(
[PsCustomObject]
$DevOpsPlan,

[string]
[Parameter(
    ValueFromPipeline=$true,
    ValueFromPipelineByPropertyName=$true)]
$ProjectRootDirPath = '.'){
    <#
        .SYNOPSIS
        an internal utility function to save a runtime DevOpsPlan object as 
        a DevOps plan archive.
    #>
    
    $devOpsPlanFilePath = Resolve-Path "$ProjectRootDirPath\.PoshDevOps\DevOpsPlan.psd1"    
    Set-Content $devOpsPlanFilePath -Value (ConvertTo-Pson -InputObject $DevOpsPlan -Depth 12 -Layers 12 -Strict)
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

function Add-DevOpsPlanStep(
[CmdletBinding(
    DefaultParameterSetName="add-DevOpsPlanStepLast")]

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
    ParameterSetName='add-DevOpsPlanStepFirst')]
$First,

[switch]
[Parameter(
    ParameterSetName='add-DevOpsPlanStepLast')]
$Last,

[string]
[Parameter(
    Mandatory=$true,
    ParameterSetName='add-DevOpsPlanStepAfter')]
$After,

[string]
[Parameter(
    Mandatory=$true,
    ParameterSetName='add-DevOpsPlanStepBefore')]
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
        Adds a new step to a DevOps plan
        
        .EXAMPLE
        Add-DevOpsPlanStep -Name "LastStep" -PackageId "DeployNupkgToAzureWebsites" -PackageVersion "0.0.3"
        
        Description:

        This command adds a DevOps plan step (named LastStep) after all existing steps

        .EXAMPLE
        Add-DevOpsPlanStep -Name "FirstStep" -PackageId "DeployNupkgToAzureWebsites" -First

        Description:

        This command adds a DevOps plan step (named FirstStep) before all existing steps

        .EXAMPLE
        Add-DevOpsPlanStep -Name "AfterSecondStep" -PackageId "DeployNupkgToAzureWebsites" -After "SecondStep"

        Description:

        This command adds a DevOps plan step (named AfterSecondStep) after the existing step named SecondStep

        .EXAMPLE
        Add-DevOpsPlanStep -Name "BeforeSecondStep" -PackageId "DeployNupkgToAzureWebsites" -Before "SecondStep"

        Description:

        This command adds a DevOps plan step (named BeforeSecondStep) before the existing step named SecondStep

    #>

    $devOpsPlan = Get-DevOpsPlan -ProjectRootDirPath $ProjectRootDirPath
    
    if($devOpsPlan.Steps.Contains($Name)){

throw "A step with name $Name already exists.`n Tip: You can remove the existing step by invoking Remove-DevOpsPlanStep"
            
    }
    else{
        
        if([string]::IsNullOrWhiteSpace($PackageVersion)){
            $PackageVersion = Get-LatestPackageVersion -PackageSources $PackageSources -PackageId $PackageId
Write-Debug "using greatest available module version : $PackageVersion"
        }


        $key = $Name
        $value = [PSCustomObject]@{'Name'=$Name;'PackageId'=$PackageId;'PackageVersion'=$PackageVersion}

        if($First.IsPresent){
        
            $devOpsPlan.Steps.Insert(0,$key,$value)
        
        }
        elseif('add-DevOpsPlanStepAfter' -eq $PSCmdlet.ParameterSetName){

            $indexOfAfter = Get-IndexOfKeyInOrderedDictionary -Key $After -OrderedDictionary $devOpsPlan.Steps
            # ensure step with key $After exists
            if($indexOfAfter -lt 0){
                throw "A DevOps step with name $After could not be found."
            }
            $devOpsPlan.Steps.Insert($indexOfAfter + 1,$key,$value)
        
        }
        elseif('add-DevOpsPlanStepBefore' -eq $PSCmdlet.ParameterSetName){        
        
            $indexOfBefore = Get-IndexOfKeyInOrderedDictionary -Key $Before -OrderedDictionary $devOpsPlan.Steps
            # ensure step with key $Before exists
            if($indexOfBefore -lt 0){
                throw "A DevOps step with name $Before could not be found."
            }
            $devOpsPlan.Steps.Insert($indexOfBefore,$key,$value)
        
        }
        else{
        
            # by default add as last step
            $devOpsPlan.Steps.Add($key, $value)        
        }

Write-Debug "saving DevOps plan"
        Save-DevOpsPlan -DevOpsPlan $devOpsPlan -ProjectRootDirPath $ProjectRootDirPath    

    }
}

function Set-DevOpsPlanParameters(

[string]
[ValidateNotNullOrEmpty()]
[Parameter(
    Mandatory=$true)]
$PoshDevOpsStepName,

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
        Sets configurable parameters of a DevOps step
        
        .EXAMPLE
        Set-DevOpsPlanParameters -PoshDevOpsStepName "GitClone" -Parameters @{GitParameters=@("status")} -Force
        
        Description:

        This command sets a parameter (named "GitParameters") for a DevOps step (named "GitClone") to @("status")
    #>

    $devOpsPlan = Get-DevOpsPlan -ProjectRootDirPath $ProjectRootDirPath
    $ciStep = $devOpsPlan.Steps.$PoshDevOpsStepName
    $parametersPropertyName = "Parameters"

Write-Debug "Checking DevOps step `"$PoshDevOpsStepName`" for property `"$parametersPropertyName`""
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
For DevOps step `"$PoshDevOpsStepName`",
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
Property `"$parametersPropertyName`" has not previously been set for DevOps step `"$PoshDevOpsStepName`"
Adding with value:
$($Parameters|Out-String)
"@
        Add-Member -InputObject $ciStep -MemberType 'NoteProperty' -Name $parametersPropertyName -Value $Parameters -Force
    }
    
    Save-DevOpsPlan -DevOpsPlan $devOpsPlan -ProjectRootDirPath $ProjectRootDirPath
}

function Remove-DevOpsPlanStep(
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

    $confirmationPromptQuery = "Are you sure you want to delete the DevOps step with name $Name`?"
    $confirmationPromptCaption = 'Confirm DevOps step removal'

    if($Force.IsPresent -or $PSCmdlet.ShouldContinue($confirmationPromptQuery,$confirmationPromptCaption)){

        $devOpsPlan = Get-DevOpsPlan -ProjectRootDirPath $ProjectRootDirPath
Write-Debug "Removing DevOps step $Name"
        $devOpsPlan.Steps.Remove($Name)
        Save-DevOpsPlan -DevOpsPlan $devOpsPlan -ProjectRootDirPath $ProjectRootDirPath
    }

}

function New-DevOpsPlan(
[string]
[Parameter(
    ValueFromPipeline=$true,
    ValueFromPipelineByPropertyName=$true)]
$ProjectRootDirPath = '.'){
    $devOpsPlanDirPath = "$(Resolve-Path $ProjectRootDirPath)\.PoshDevOps"

    if(!(Test-Path $devOpsPlanDirPath)){    
        $templatesDirPath = "$PSScriptRoot\Templates"

Write-Debug "Creating a directory for the DevOps plan at path $devOpsPlanDirPath"
        New-Item -ItemType Directory -Path $devOpsPlanDirPath

Write-Debug "Adding default files to path $devOpsPlanDirPath"
        Copy-Item -Path "$templatesDirPath\DevOpsPlan.psd1" $devOpsPlanDirPath
    }
    else{        
throw ".PoshDevOps directory already exists at $devOpsPlanDirPath. If you are trying to recreate your DevOps plan from scratch you must invoke Remove-DevOpsPlan first"
    }
}

function Remove-DevOpsPlan(
[switch]$Force,
[string]
[Parameter(
    ValueFromPipeline=$true,
    ValueFromPipelineByPropertyName=$true)]
$ProjectRootDirPath = '.'){
    
    $devOpsPlanDirPath = Resolve-Path "$ProjectRootDirPath\.PoshDevOps"

    $confirmationPromptQuery = "Are you sure you want to delete the DevOps plan located at $DevOpsPlanDirPath`?"
    $confirmationPromptCaption = 'Confirm DevOps plan removal'

    if($Force.IsPresent -or $PSCmdlet.ShouldContinue($confirmationPromptQuery,$confirmationPromptCaption)){
        Remove-Item -Path $devOpsPlanDirPath -Recurse -Force
    }
}

function Invoke-DevOpsPlan(

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
    
    $devOpsPlanDirPath = Resolve-Path "$ProjectRootDirPath\.PoshDevOps"
    $devOpsPlanFilePath = "$devOpsPlanDirPath\DevOpsPlan.psd1"
    $packagesDirPath = "$devOpsPlanDirPath\Packages"

    if(Test-Path $devOpsPlanFilePath){

        EnsureNuGetInstalled

        $DevOpsPlan = Get-DevOpsPlan -ProjectRootDirPath $ProjectRootDirPath

        foreach($step in $DevOpsPlan.Steps.Values){
                    
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

Write-Debug "Ensuring DevOps step module package installed"
            nuget install $step.PackageId -Version $step.PackageVersion -OutputDirectory $packagesDirPath -Source $PackageSources -NonInteractive

            $moduleDirPath = "$packagesDirPath\$($step.PackageId).$($step.PackageVersion)\tools\$($step.PackageId)"
Write-Debug "Importing module located at: $moduleDirPath"
            Import-Module $moduleDirPath -Force

Write-Debug `
@"
Invoking DevOps step $($step.Name) with parameters: 
$($stepParameters|Out-String)
"@
            # Parameters must be PSCustomObject so [Parameter(ValueFromPipelineByPropertyName = $true)] works
            [PSCustomObject]$stepParameters.Clone() | Invoke-PoshDevOpsTask

        }
    }
    else{

throw "DevOpsPlan.psd1 not found at: $devOpsPlanFilePath"

    }
}

Export-ModuleMember -Function Invoke-DevOpsPlan,New-DevOpsPlan,Remove-DevOpsPlan,Add-DevOpsPlanStep,Set-DevOpsPlanParameters,Remove-DevOpsPlanStep,Get-DevOpsPlan
