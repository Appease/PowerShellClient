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

function Get-PoshDevOpsTaskGroup(
[string]
[Parameter(
    ValueFromPipeline=$true,
    ValueFromPipelineByPropertyName=$true)]
$ProjectRootDirPath = '.'){
    <#
        .SYNOPSIS
        parses a task group file
    #>

    $taskGroupFilePath = Resolve-Path "$ProjectRootDirPath\.PoshDevOps\TaskGroup.psd1"   
Write-Output (Get-Content $taskGroupFilePath | Out-String | ConvertFrom-Pson)

}

function Save-TaskGroup(
[PsCustomObject]
$TaskGroup,

[string]
[Parameter(
    ValueFromPipeline=$true,
    ValueFromPipelineByPropertyName=$true)]
$ProjectRootDirPath = '.'){
    <#
        .SYNOPSIS
        an internal utility function to snapshot and save a TaskGroup to disk
    #>
    
    $taskGroupFilePath = Resolve-Path "$ProjectRootDirPath\.PoshDevOps\TaskGroup.psd1"    
    Set-Content $taskGroupFilePath -Value (ConvertTo-Pson -InputObject $TaskGroup -Depth 12 -Layers 12 -Strict)
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
    DefaultParameterSetName="add-TaskLast")]

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
    ParameterSetName='add-TaskFirst')]
$First,

[switch]
[Parameter(
    ParameterSetName='add-TaskLast')]
$Last,

[string]
[Parameter(
    Mandatory=$true,
    ParameterSetName='add-TaskAfter')]
$After,

[string]
[Parameter(
    Mandatory=$true,
    ParameterSetName='add-TaskBefore')]
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
        Adds a new task to a task group
        
        .EXAMPLE
        Add-PoshDevOpsTask -Name "LastTask" -PackageId "DeployNupkgToAzureWebsites" -PackageVersion "0.0.3"
        
        Description:

        This command adds a task (named LastTask) after all existing tasks

        .EXAMPLE
        Add-PoshDevOpsTask -Name "FirstTask" -PackageId "DeployNupkgToAzureWebsites" -First

        Description:

        This command adds a task (named FirstTask) before all existing tasks

        .EXAMPLE
        Add-PoshDevOpsTask -Name "AfterSecondTask" -PackageId "DeployNupkgToAzureWebsites" -After "SecondTask"

        Description:

        This command adds a task (named AfterSecondTask) after the existing task named SecondTask

        .EXAMPLE
        Add-PoshDevOpsTask -Name "BeforeSecondTask" -PackageId "DeployNupkgToAzureWebsites" -Before "SecondTask"

        Description:

        This command adds a task (named BeforeSecondTask) before the existing task named SecondTask

    #>

    $taskGroup = Get-PoshDevOpsTaskGroup -ProjectRootDirPath $ProjectRootDirPath
    
    if($taskGroup.Tasks.Contains($Name)){

throw "A task with name $Name already exists.`n Tip: You can remove the existing task by invoking Remove-PoshDevOpsTask"
            
    }
    else{
        
        if([string]::IsNullOrWhiteSpace($PackageVersion)){
            $PackageVersion = Get-LatestPackageVersion -PackageSources $PackageSources -PackageId $PackageId
Write-Debug "using greatest available module version : $PackageVersion"
        }


        $key = $Name
        $value = [PSCustomObject]@{'Name'=$Name;'PackageId'=$PackageId;'PackageVersion'=$PackageVersion}

        if($First.IsPresent){
        
            $taskGroup.Tasks.Insert(0,$key,$value)
        
        }
        elseif('add-TaskAfter' -eq $PSCmdlet.ParameterSetName){

            $indexOfAfter = Get-IndexOfKeyInOrderedDictionary -Key $After -OrderedDictionary $taskGroup.Tasks
            # ensure task with key $After exists
            if($indexOfAfter -lt 0){
                throw "A task with name $After could not be found."
            }
            $taskGroup.Tasks.Insert($indexOfAfter + 1,$key,$value)
        
        }
        elseif('add-TaskBefore' -eq $PSCmdlet.ParameterSetName){        
        
            $indexOfBefore = Get-IndexOfKeyInOrderedDictionary -Key $Before -OrderedDictionary $taskGroup.Tasks
            # ensure task with key $Before exists
            if($indexOfBefore -lt 0){
                throw "A task with name $Before could not be found."
            }
            $taskGroup.Tasks.Insert($indexOfBefore,$key,$value)
        
        }
        else{
        
            # by default add as last task
            $taskGroup.Tasks.Add($key, $value)        
        }

Write-Debug "saving task group"
        Save-TaskGroup -TaskGroup $taskGroup -ProjectRootDirPath $ProjectRootDirPath    

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
        Sets configurable parameters of a task
        
        .EXAMPLE
        Set-PoshDevOpsTaskParameters -PoshDevOpsTaskName "GitClone" -Parameters @{GitParameters=@("status")} -Force
        
        Description:

        This command sets a parameter (named "GitParameters") for a task (named "GitClone") to @("status")
    #>

    $taskGroup = Get-PoshDevOpsTaskGroup -ProjectRootDirPath $ProjectRootDirPath
    $ciTask = $taskGroup.Tasks.$PoshDevOpsTaskName
    $parametersPropertyName = "Parameters"

Write-Debug "Checking task `"$PoshDevOpsTaskName`" for property `"$parametersPropertyName`""
    $parametersPropertyValue = $ciTask.$parametersPropertyName    
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
For task `"$PoshDevOpsTaskName`",
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
Property `"$parametersPropertyName`" has not previously been set for task `"$PoshDevOpsTaskName`"
Adding with value:
$($Parameters|Out-String)
"@
        Add-Member -InputObject $ciTask -MemberType 'NoteProperty' -Name $parametersPropertyName -Value $Parameters -Force
    }
    
    Save-TaskGroup -TaskGroup $taskGroup -ProjectRootDirPath $ProjectRootDirPath
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

    $confirmationPromptQuery = "Are you sure you want to delete the task with name $Name`?"
    $confirmationPromptCaption = 'Confirm task removal'

    if($Force.IsPresent -or $PSCmdlet.ShouldContinue($confirmationPromptQuery,$confirmationPromptCaption)){

        $taskGroup = Get-PoshDevOpsTaskGroup -ProjectRootDirPath $ProjectRootDirPath
Write-Debug "Removing task $Name"
        $taskGroup.Tasks.Remove($Name)
        Save-TaskGroup -TaskGroup $taskGroup -ProjectRootDirPath $ProjectRootDirPath
    }

}

function New-PoshDevOpsTaskGroup(
[string]
[Parameter(
    ValueFromPipeline=$true,
    ValueFromPipelineByPropertyName=$true)]
$ProjectRootDirPath = '.'){
    $taskGroupDirPath = "$(Resolve-Path $ProjectRootDirPath)\.PoshDevOps"

    if(!(Test-Path $taskGroupDirPath)){    
        $templatesDirPath = "$PSScriptRoot\Templates"

Write-Debug "Creating a directory for the task group at path $taskGroupDirPath"
        New-Item -ItemType Directory -Path $taskGroupDirPath

Write-Debug "Adding default files to path $taskGroupDirPath"
        Copy-Item -Path "$templatesDirPath\TaskGroup.psd1" $taskGroupDirPath
    }
    else{        
throw ".PoshDevOps directory already exists at $taskGroupDirPath. If you are trying to recreate your task group from scratch you must invoke Remove-PoshDevOpsTaskGroup first"
    }
}

function Remove-PoshDevOpsTaskGroup(
[switch]$Force,
[string]
[Parameter(
    ValueFromPipeline=$true,
    ValueFromPipelineByPropertyName=$true)]
$ProjectRootDirPath = '.'){
    
    $taskGroupDirPath = Resolve-Path "$ProjectRootDirPath\.PoshDevOps"

    $confirmationPromptQuery = "Are you sure you want to delete the task group located at $TaskGroupDirPath`?"
    $confirmationPromptCaption = 'Confirm task group removal'

    if($Force.IsPresent -or $PSCmdlet.ShouldContinue($confirmationPromptQuery,$confirmationPromptCaption)){
        Remove-Item -Path $taskGroupDirPath -Recurse -Force
    }
}

function Invoke-PoshDevOpsTaskGroup(

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
    
    $taskGroupDirPath = Resolve-Path "$ProjectRootDirPath\.PoshDevOps"
    $taskGroupFilePath = "$taskGroupDirPath\TaskGroup.psd1"
    $packagesDirPath = "$taskGroupDirPath\Packages"

    if(Test-Path $taskGroupFilePath){

        EnsureNuGetInstalled

        $TaskGroup = Get-PoshDevOpsTaskGroup -ProjectRootDirPath $ProjectRootDirPath

        foreach($task in $TaskGroup.Tasks.Values){
                    
            if($Parameters.($task.Name)){

                if($task.Parameters){

Write-Debug "Adding union of passed parameters and archived parameters to pipeline. Passed parameters will override archived parameters"
                
                    $taskParameters = Get-UnionOfHashtables -Source1 $Parameters.($task.Name) -Source2 $task.Parameters

                }
                else{

Write-Debug "Adding passed parameters to pipeline"

                    $taskParameters = $Parameters.($task.Name)
            
                }

            }
            elseif($task.Parameters){

Write-Debug "Adding archived parameters to pipeline"    
                $taskParameters = $task.Parameters

            }
            else{
                
                $taskParameters = @{}
            
            }

Write-Debug "Adding automatic parameters to pipeline"
            
            $taskParameters.PoshDevOpsProjectRootDirPath = (Resolve-Path $ProjectRootDirPath)
            $taskParameters.PoshDevOpsTaskName = $task.Name

Write-Debug "Ensuring task module package installed"
            nuget install $task.PackageId -Version $task.PackageVersion -OutputDirectory $packagesDirPath -Source $PackageSources -NonInteractive

            $moduleDirPath = "$packagesDirPath\$($task.PackageId).$($task.PackageVersion)\tools\$($task.PackageId)"
Write-Debug "Importing module located at: $moduleDirPath"
            Import-Module $moduleDirPath -Force

Write-Debug `
@"
Invoking task $($task.Name) with parameters: 
$($taskParameters|Out-String)
"@
            # Parameters must be PSCustomObject so [Parameter(ValueFromPipelineByPropertyName = $true)] works
            [PSCustomObject]$taskParameters.Clone() | Invoke-PoshDevOpsTask

        }
    }
    else{

throw "TaskGroup.psd1 not found at: $taskGroupFilePath"

    }
}

Export-ModuleMember -Function Invoke-PoshDevOpsTaskGroup,New-PoshDevOpsTaskGroup,Remove-PoshDevOpsTaskGroup,Add-PoshDevOpsTask,Set-PoshDevOpsTaskParameters,Remove-PoshDevOpsTask,Get-PoshDevOpsTaskGroup
