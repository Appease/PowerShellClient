Import-Module "$PSScriptRoot\PoshDevOpsPackageManager" -Force -Global
Import-Module "$PSScriptRoot\TaskGroupStorage" -Force -Global

function Get-UnionOfHashtables(
[Hashtable]
[ValidateNotNull()]
[Parameter(
    ValueFromPipelineByPropertyName=$true)]
$Source1,

[Hashtable]
[ValidateNotNull()]
[Parameter(
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
[ValidateNotNullOrEmpty()]
$PackageSource= $DefaultPackageSources,

[string]
[ValidateScript({Test-Path $_ -PathType Container})]
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
            $PackageVersion = Get-LatestPackageVersion -Source $PackageSource -Id $PackageId
Write-Debug "using greatest available package version : $PackageVersion"
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

        Save-PoshDevOpsTaskGroup -TaskGroup $taskGroup -ProjectRootDirPath $ProjectRootDirPath    

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
[ValidateScript({Test-Path $_ -PathType Container})]
[Parameter(
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
    
    Save-PoshDevOpsTaskGroup -TaskGroup $taskGroup -ProjectRootDirPath $ProjectRootDirPath
}

function Remove-PoshDevOpsTask(
[string]
[ValidateNotNullOrEmpty()]
[Parameter(
    Mandatory=$true)]
$Name,

[switch]$Force,

[string]
[ValidateScript({Test-Path $_ -PathType Container})]
[Parameter(
    ValueFromPipelineByPropertyName=$true)]
$ProjectRootDirPath = '.'){

    $confirmationPromptQuery = "Are you sure you want to delete the task with name $Name`?"
    $confirmationPromptCaption = 'Confirm task removal'

    if($Force.IsPresent -or $PSCmdlet.ShouldContinue($confirmationPromptQuery,$confirmationPromptCaption)){

        $taskGroup = Get-PoshDevOpsTaskGroup -ProjectRootDirPath $ProjectRootDirPath
Write-Debug "Removing task $Name"
        $taskGroup.Tasks.Remove($Name)
        Save-PoshDevOpsTaskGroup -TaskGroup $taskGroup -ProjectRootDirPath $ProjectRootDirPath
    }

}

function New-PoshDevOpsTaskGroup(

[string]
[ValidateNotNullOrEmpty()]
[Parameter(
    ValueFromPipelineByPropertyName=$true)]
$Name,

[string]
[ValidateScript({Test-Path $_ -PathType Container})]
[Parameter(
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

function Update-PoshDevOpsPackage(

[CmdletBinding(
    DefaultParameterSetName="Update-All")]

[string[]]
[ValidateCount( 1, [Int]::MaxValue)]
[Parameter(
    Mandatory=$true,
    ValueFromPipelineByPropertyName=$true,
    ParameterSetName="Update-Single")]
[Parameter(
    Mandatory=$true,
    ValueFromPipelineByPropertyName=$true,
    ParameterSetName="Update-Multiple")]
$Id,

[string]
[Parameter(
    Mandatory=$true,
    ValueFromPipelineByPropertyName=$true,
    ParameterSetName="Update-Single")]
$Version,

[switch]
[Parameter(
    ParameterSetName="Update-All")]
$All,

[string[]]
[ValidateCount( 1, [Int]::MaxValue)]
[ValidateNotNullOrEmpty()]
[Parameter(
    ValueFromPipelineByPropertyName=$true)]
$Source = $DefaultPackageSources,

[String]
[ValidateScript({Test-Path $_ -PathType Container})]
[Parameter(
    ValueFromPipelineByPropertyName=$true)]
$ProjectRootDirPath='.'){

    $taskGroupDirPath = Resolve-Path "$ProjectRootDirPath\.PoshDevOps"
    $taskGroupFilePath = "$taskGroupDirPath\TaskGroup.psd1"
    $packagesDirPath = "$taskGroupDirPath\Packages"
    $taskGroup = Get-PoshDevOpsTaskGroup -ProjectRootDirPath $ProjectRootDirPath 

    # build up list of package updates
    $packageUpdates = @{}
    If('Update-Multiple' -eq $PSCmdlet.ParameterSetName){

        foreach($packageId in $Id){

            $packageUpdates.Add($packageId,(Get-LatestPackageVersion -Source $Source -Id $packageId))

        }
    }
    ElseIf('Update-Single' -eq $PSCmdlet.ParameterSetName){
        
        if($Id.Length -ne 1){
            throw "Updating to an explicit package version is only allowed when updating a single package"
        }

        $packageUpdates.Add($Id,$Version)
    }
    Else{        
        
        foreach($task in $taskGroup.Tasks.Values){

            $packageUpdates.Add($task.PackageId,(Get-LatestPackageVersion -Source $Source -Id $task.PackageId))
        
        }
    }

    foreach($task in $taskGroup.Tasks.Values){

        $updatedPackageVersion = $packageUpdates.($task.PackageId)

        if($null -ne $updatedPackageVersion){

            Uninstall-PoshDevOpsPackageIfExists -Id $task.PackageId -Version $task.PackageVersion -ProjectRootDirPath $ProjectRootDirPath

Write-Debug `
@"
Updating task (with name $($task.Name)) package (with id $($task.PackageId))
from version: $($task.PackageVersion)
to version: $($updatedPackageVersion)
"@
            $task.PackageVersion = $updatedPackageVersion

        }
    }

    Save-PoshDevOpsTaskGroup -TaskGroup $taskGroup -ProjectRootDirPath $ProjectRootDirPath

}

function Invoke-PoshDevOpsTaskGroup(

[Hashtable]
[Parameter(
    ValueFromPipeline=$true,
    ValueFromPipelineByPropertyName=$true)]
$Parameters,

[string[]]
[ValidateCount( 1, [Int]::MaxValue)]
[Parameter(
    ValueFromPipelineByPropertyName=$true)]
$PackageSource = $DefaultPackageSources,

[String]
[ValidateScript({Test-Path $_ -PathType Container})]
[Parameter(
    ValueFromPipelineByPropertyName=$true)]
$ProjectRootDirPath='.'){
    
    $taskGroupDirPath = Resolve-Path "$ProjectRootDirPath\.PoshDevOps"
    $taskGroupFilePath = "$taskGroupDirPath\TaskGroup.psd1"
    $packagesDirPath = "$taskGroupDirPath\Packages"

    if(Test-Path $taskGroupFilePath){

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
            Install-PoshDevOpsPackage -Id $task.PackageId -Version $task.PackageVersion -Source $PackageSource

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

Export-ModuleMember -Function Invoke-PoshDevOpsTaskGroup
Export-ModuleMember -Function New-PoshDevOpsTaskGroup
Export-ModuleMember -Function Remove-PoshDevOpsTaskGroup
Export-ModuleMember -Function Update-PoshDevOpsPackage
Export-ModuleMember -Function Add-PoshDevOpsTask
Export-ModuleMember -Function Set-PoshDevOpsTaskParameters
Export-ModuleMember -Function Remove-PoshDevOpsTask
Export-ModuleMember -Function Get-PoshDevOpsTaskGroup
