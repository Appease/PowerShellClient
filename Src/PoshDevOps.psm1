Import-Module "$PSScriptRoot\PoshDevOpsPackageManager" -Force -Global
Import-Module "$PSScriptRoot\TaskGroupStorage" -Force -Global
Import-Module "$PSScriptRoot\HashtableExtensions" -Force -Global
Import-Module "$PSScriptRoot\OrderedDictionaryExtensions" -Force -Global

function Add-PoshDevOpsTask(
[CmdletBinding(
    DefaultParameterSetName="add-TaskLast")]

[string]
[ValidateNotNullOrEmpty()]
[Parameter(
    Mandatory=$true)]
$TaskGroupName,

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

[switch]
$Force,

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
        Add-PoshDevOpsTask -TaskGroup "Azure" -Name "LastTask" -PackageId "DeployNupkgToAzureWebsites" -PackageVersion "0.0.3"
        
        Description:

        This command adds task "LastTask" after all existing tasks in task group "Azure"

        .EXAMPLE
        Add-PoshDevOpsTask -TaskGroup "Azure" -Name "FirstTask" -PackageId "DeployNupkgToAzureWebsites" -First

        Description:

        This command adds task "FirstTask" before all existing tasks in task group "Azure"

        .EXAMPLE
        Add-PoshDevOpsTask -TaskGroup "Azure" -Name "AfterSecondTask" -PackageId "DeployNupkgToAzureWebsites" -After "SecondTask"

        Description:

        This command adds task "AfterSecondTask" after the existing task "SecondTask" in task group "Azure"

        .EXAMPLE
        Add-PoshDevOpsTask -TaskGroup "Azure" -Name "BeforeSecondTask" -PackageId "DeployNupkgToAzureWebsites" -Before "SecondTask"

        Description:

        This command adds task "BeforeSecondTask" before the existing task "SecondTask" in task group "Azure"

    #>

        
        if([string]::IsNullOrWhiteSpace($PackageVersion)){
            $PackageVersion = Get-LatestPackageVersion -Source $PackageSource -Id $PackageId
Write-Debug "using greatest available package version : $PackageVersion"
        }
                
        if($First.IsPresent){
        
            $TaskIndex = 0
        
        }
        elseif('add-TaskAfter' -eq $PSCmdlet.ParameterSetName){
            
            $TaskGroup = TaskGroupStorage\Get-TaskGroup -Name $TaskGroupName -ProjectRootDirPath $ProjectRootDirPath
            $indexOfAfter = Get-IndexOfKeyInOrderedDictionary -Key $After -OrderedDictionary $TaskGroup.Tasks
            # ensure task with key $After exists
            if($indexOfAfter -lt 0){
                throw "A task with name $After could not be found."
            }
            $TaskIndex = $indexOfAfter + 1
        
        }
        elseif('add-TaskBefore' -eq $PSCmdlet.ParameterSetName){        
        
            $TaskGroup = TaskGroupStorage\Get-TaskGroup -Name $TaskGroupName -ProjectRootDirPath $ProjectRootDirPath
            $indexOfBefore = Get-IndexOfKeyInOrderedDictionary -Key $Before -OrderedDictionary $TaskGroup.Tasks
            # ensure task with key $Before exists
            if($indexOfBefore -lt 0){
                throw "A task with name $Before could not be found."
            }
            $TaskIndex = $indexOfBefore
        
        }
        else{
        
            $TaskGroup = TaskGroupStorage\Get-TaskGroup -Name $TaskGroupName -ProjectRootDirPath $ProjectRootDirPath
            $TaskIndex = $TaskGroup.Tasks.Count  
        }

        TaskGroupStorage\Add-Task `
            -TaskGroupName $TaskGroupName `
            -Name $Name `
            -PackageId $PackageId `
            -PackageVersion $PackageVersion `
            -Index $TaskIndex `
            -Force:$Force `
            -ProjectRootDirPath $ProjectRootDirPath
}

function Set-PoshDevOpsTaskParameter(

[string]
[ValidateNotNullOrEmpty()]
[Parameter(
    Mandatory=$true)]
$TaskGroupName,

[string]
[ValidateNotNullOrEmpty()]
[Parameter(
    Mandatory=$true)]
$TaskName,

[string]
[ValidateNotNullOrEmpty()]
[Parameter(
    Mandatory=$true)]
$Name,

[object]
[Parameter(
    Mandatory=$true)]
$Value,

[switch]
$Force,

[string]
[ValidateScript({Test-Path $_ -PathType Container})]
[Parameter(
    ValueFromPipelineByPropertyName=$true)]
$ProjectRootDirPath = '.'){
    <#
        .SYNOPSIS
        Sets configurable parameters of a task
        
        .EXAMPLE
        Set-PoshDevOpsTaskParameters -TaskGroupName Build -TaskName GitClone -Name GitParameters -Value Status -Force
        
        Description:

        This command sets the parameter "GitParameters" to "Status" for a task "GitClone" in task group "Build"
    #>

    TaskGroupStorage\Set-TaskParameter `
        -TaskGroupName $TaskGroupName `
        -TaskName $TaskName `
        -Name $Name `
        -Value $Value `
        -Force:$Force
}

function Remove-PoshDevOpsTask(

[string]
[ValidateNotNullOrEmpty()]
[Parameter(
    Mandatory=$true)]
$TaskGroupName,

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

        TaskGroupStorage\Remove-Task -TaskGroupName $TaskGroupName -Name $Name -ProjectRootDirPath $ProjectRootDirPath

    }

}

function New-PoshDevOpsTaskGroup(

[string]
[ValidateNotNullOrEmpty()]
[Parameter(
    Mandatory=$true,
    ValueFromPipelineByPropertyName=$true)]
$Name,

[switch]
$Force,

[string]
[ValidateScript({Test-Path $_ -PathType Container})]
[Parameter(
    ValueFromPipelineByPropertyName=$true)]
$ProjectRootDirPath = '.'){
    
    $TaskGroup = @{Name=$Name;Tasks=[ordered]@{}}

    TaskGroupStorage\Add-TaskGroup -Value $TaskGroup -Force:$Force -ProjectRootDirPath $ProjectRootDirPath
}

function Update-PoshDevOpsPackage(

[CmdletBinding(
    DefaultParameterSetName="Update-All")]

[string]
[ValidateNotNullOrEmpty()]
[Parameter(
    Mandatory=$true)]
$TaskGroupName,

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

    $TaskGroup = TaskGroupStorage\Get-TaskGroup -Name $TaskGroupName -ProjectRootDirPath $ProjectRootDirPath

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
Updating task "$($task.Name)" package "$($task.PackageId)"
from version "$($task.PackageVersion)"
to version "$($updatedPackageVersion)"
"@
            TaskGroupStorage\Update-TaskPackageVersion `
                -TaskGroupName $TaskGroupName `
                -TaskName $task.Name `
                -PackageVersion $updatedPackageVersion `
                -ProjectRootDirPath $ProjectRootDirPath
        }
    }
}

function Invoke-PoshDevOpsTaskGroup(

[string]
[ValidateNotNullOrEmpty()]
[Parameter(
    Mandatory=$true)]
$Name,

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
    
    $TaskGroup = TaskGroupStorage\Get-TaskGroup -Name $Name -ProjectRootDirPath $ProjectRootDirPath

    if($TaskGroup){        

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

            $moduleDirPath = "$ProjectRootDirPath\.PoshDevOps\Packages\$($task.PackageId).$($task.PackageVersion)\tools\$($task.PackageId)"
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
Export-ModuleMember -Function Set-PoshDevOpsTaskParameter
Export-ModuleMember -Function Remove-PoshDevOpsTask
Export-ModuleMember -Function Get-PoshDevOpsTaskGroup
