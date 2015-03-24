Import-Module "$PSScriptRoot\Pson" -Force -Global
Import-Module "$PSScriptRoot\..\OrderedDictionaryExtensions" -Force -Global

function Get-TaskGroup(

[string]
[ValidateNotNullOrEmpty()]
[Parameter(
    Mandatory=$true,
    ValueFromPipelineByPropertyName=$true)]
$Name,

[string]
[ValidateScript({Test-Path $_ -PathType Container})]
[Parameter(
    ValueFromPipelineByPropertyName=$true)]
$ProjectRootDirPath = '.'){
    <#
        .SYNOPSIS
        an internal utility function that retrieves a task group from storage
    #>

    $TaskGroupFilePath = Resolve-Path "$ProjectRootDirPath\.PoshDevOps\$Name.psd1"   
    Write-Output (Get-Content $TaskGroupFilePath | Out-String | ConvertFrom-Pson)

}

function Add-TaskGroup(
[PsCustomObject]
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
        an internal utility function that saves a task group to storage
    #>

    $TaskGroupFilePath = "$ProjectRootDirPath\.PoshDevOps\$($Value.Name).psd1"

    # guard against unintentionally overwriting existing task group
    if(!$Force.IsPresent -and (Test-Path $TaskGroupFilePath)){
throw `
@"
Task group "$($Value.Name)" already exists
for project "$(Resolve-Path $ProjectRootDirPath)".

Task group names must be unique.
If you want to overwrite the existing task group use the -Force parameter
"@
    }

Write-Debug `
@"
Creating task group file at:
$TaskGroupFilePath
Creating...
"@

    New-Item -Path $TaskGroupFilePath -ItemType File -Force        
    Set-Content $TaskGroupFilePath -Value (ConvertTo-Pson -InputObject $Value -Depth 12 -Layers 12 -Strict) -Force
    
}



function Rename-TaskGroup(
[string]
[ValidateNotNullOrEmpty()]
$OldName,

[string]
[ValidateNotNullOrEmpty()]
$NewName,

[switch]
$Force,

[string]
[ValidateScript({Test-Path $_ -PathType Container})]
[Parameter(
    ValueFromPipelineByPropertyName=$true)]
$ProjectRootDirPath = '.'){
    <#
        .SYNOPSIS
        an internal utility function that updates the name of a task group in storage
    #>
    
    $OldTaskGroupFilePath = "$ProjectRootDirPath\.PoshDevOps\$OldName.psd1"
    $NewTaskGroupFilePath = "$ProjectRootDirPath\.PoshDevOps\$NewName.psd1"

    # guard against unintentionally overwriting existing task group
    if(!$Force.IsPresent -and (Test-Path $NewTaskGroupFilePath)){
throw `
@"
Task group "$NewName" already exists
for project "$(Resolve-Path $ProjectRootDirPath)".

Task group names must be unique.
If you want to overwrite the existing task group use the -Force parameter
"@
    }

    # fetch task group
    $TaskGroup = Get-TaskGroup -Name $OldName -ProjectRootDirPath $ProjectRootDirPath

    # update name
    $TaskGroup.Name = $NewName

        
    #save
    mv $OldTaskGroupFilePath $NewTaskGroupFilePath -Force
    sc $TaskGroupFilePath -Value (ConvertTo-Pson -InputObject $TaskGroup -Depth 12 -Layers 12 -Strict) -Force
}

function Remove-TaskGroup(

[string]
[ValidateNotNullOrEmpty()]
[Parameter(
    Mandatory=$true,
    ValueFromPipelineByPropertyName=$true)]
$Name,

[string]
[ValidateScript({Test-Path $_ -PathType Container})]
[Parameter(
    ValueFromPipelineByPropertyName=$true)]
$ProjectRootDirPath = '.'){
    <#
        .SYNOPSIS
        an internal utility function that removes a task group from storage
    #>
    
    $TaskGroupFilePath = Resolve-Path "$ProjectRootDirPath\.PoshDevOps\$Name.psd1"
    
    Remove-Item -Path $TaskGroupFilePath -Force
}

function Add-Task(
[string]
[ValidateNotNullOrEmpty()]
[Parameter(
    Mandatory=$true,
    ValueFromPipelineByPropertyName=$true)]
$TaskGroupName,

[string]
[ValidateNotNullOrEmpty()]
[Parameter(
    Mandatory=$true,
    ValueFromPipelineByPropertyName=$true)]
$Name,

[string]
[ValidateNotNullOrEmpty()]
[Parameter(
    Mandatory=$true,
    ValueFromPipelineByPropertyName=$true)]
$PackageId,

[string]
[ValidateNotNullOrEmpty()]
[Parameter(
    Mandatory=$true,
    ValueFromPipelineByPropertyName=$true)]
$PackageVersion,

[int]
[ValidateScript({$_ -gt -1})]
[Parameter(
    Mandatory=$true,
    ValueFromPipelineByPropertyName=$true)]
$Index,

[switch]
$Force,

[string]
[ValidateScript({Test-Path $_ -PathType Container})]
[Parameter(
    ValueFromPipelineByPropertyName=$true)]
$ProjectRootDirPath = '.'){
    <#
        .SYNOPSIS
        an internal utility function that adds a task to a task group in storage
    #>    
    
    $TaskGroupFilePath = "$ProjectRootDirPath\.PoshDevOps\$TaskGroupName.psd1"

    # fetch task group
    $TaskGroup = Get-TaskGroup -Name $TaskGroupName -ProjectRootDirPath $ProjectRootDirPath

    # guard against unintentionally overwriting existing tasks
    if(!$Force.IsPresent -and ($TaskGroup.Tasks.$Name)){
throw `
@"
Task "$Name" already exists in task group "$TaskGroupName"
for project "$(Resolve-Path $ProjectRootDirPath)".

Task names must be unique.
If you want to overwrite the existing task use the -Force parameter
"@
    }

    # construct task object
    $Task = @{Name=$Name;PackageId=$PackageId;PackageVersion=$PackageVersion;}

    # add task to taskgroup
    $TaskGroup.Tasks.Insert($Index,$Name,$Task)

    # save
    sc $TaskGroupFilePath -Value (ConvertTo-Pson -InputObject $TaskGroup -Depth 12 -Layers 12 -Strict) -Force
}

function Remove-Task(
[string]
[ValidateNotNullOrEmpty()]
[Parameter(
    Mandatory=$true,
    ValueFromPipelineByPropertyName=$true)]
$TaskGroupName,

[string]
[ValidateNotNullOrEmpty()]
[Parameter(
    Mandatory=$true,
    ValueFromPipelineByPropertyName=$true)]
$Name,

[string]
[ValidateScript({Test-Path $_ -PathType Container})]
[Parameter(
    ValueFromPipelineByPropertyName=$true)]
$ProjectRootDirPath = '.'){
    
    $TaskGroupFilePath = "$ProjectRootDirPath\.PoshDevOps\$TaskGroupName.psd1"
    
    # fetch task group
    $TaskGroup = Get-TaskGroup -Name $TaskGroupName -ProjectRootDirPath $ProjectRootDirPath

    # remove task
    $TaskGroup.Tasks.Remove($Name)

    # save
    sc $TaskGroupFilePath -Value (ConvertTo-Pson -InputObject $TaskGroup -Depth 12 -Layers 12 -Strict) -Force
}

function Rename-Task(
[string]
[ValidateNotNullOrEmpty()]
[Parameter(
    Mandatory=$true,
    ValueFromPipelineByPropertyName=$true)]
$TaskGroupName,

[string]
[ValidateNotNullOrEmpty()]
[Parameter(
    Mandatory=$true,
    ValueFromPipelineByPropertyName=$true)]
$OldName,

[string]
[ValidateNotNullOrEmpty()]
[Parameter(
    Mandatory=$true,
    ValueFromPipelineByPropertyName=$true)]
$NewName,

[switch]
$Force,

[string]
[ValidateScript({Test-Path $_ -PathType Container})]
[Parameter(
    ValueFromPipelineByPropertyName=$true)]
$ProjectRootDirPath = '.'){
    
    $TaskGroupFilePath = "$ProjectRootDirPath\.PoshDevOps\$TaskGroupName.psd1"
    
    # fetch task group
    $TaskGroup = Get-TaskGroup -Name $TaskGroupName -ProjectRootDirPath $ProjectRootDirPath

    # fetch task
    $Task = $TaskGroup.Tasks.$OldName

    # handle task not found
    if(!$Task){
throw `
@"
Task "$TaskName" not found in task group "$TaskGroupName"
for project "$(Resolve-Path $ProjectRootDirPath)".
"@
    }

    # guard against unintentionally overwriting existing task
    if(!$Force.IsPresent -and ($TaskGroup.Tasks.$NewName)){
throw `
@"
Task "$NewName" already exists in task group "$TaskGroupName"
for project "$(Resolve-Path $ProjectRootDirPath)".

Task names must be unique.
If you want to overwrite the existing task use the -Force parameter
"@
    }

    # get task index
    $Index = Get-IndexOfKeyInOrderedDictionary -Key $OldName -OrderedDictionary $TaskGroup.Tasks

    # update name
    $Task.Name = $NewName

    # remove old record
    $TaskGroup.Tasks.Remove($OldName)

    # insert new record
    $TaskGroup.Tasks.Insert($Index,$Task.Name,$Task)

    # save
    sc $TaskGroupFilePath -Value (ConvertTo-Pson -InputObject $TaskGroup -Depth 12 -Layers 12 -Strict) -Force
}

function Update-TaskPackageVersion(
[string]
[ValidateNotNullOrEmpty()]
[Parameter(
    Mandatory=$true,
    ValueFromPipelineByPropertyName=$true)]
$TaskGroupName,

[string]
[ValidateNotNullOrEmpty()]
[Parameter(
    Mandatory=$true,
    ValueFromPipelineByPropertyName=$true)]
$TaskName,

[string]
[ValidateNotNullOrEmpty()]
[Parameter(
    Mandatory=$true,
    ValueFromPipelineByPropertyName=$true)]
$PackageVersion,

[string]
[ValidateScript({Test-Path $_ -PathType Container})]
[Parameter(
    ValueFromPipelineByPropertyName=$true)]
$ProjectRootDirPath = '.'){
    
    $TaskGroupFilePath = "$ProjectRootDirPath\.PoshDevOps\$TaskGroupName.psd1"
    
    # fetch task group
    $TaskGroup = Get-TaskGroup -Name $TaskGroupName -ProjectRootDirPath $ProjectRootDirPath

    # fetch task
    $Task = $TaskGroup.Tasks.$TaskName

    # handle task not found
    if(!$Task){
throw `
@"
Task "$TaskName" not found in task group "$TaskGroupName"
for project "$(Resolve-Path $ProjectRootDirPath)".
"@
    }

    # update task version
    $Task.PackageVersion = $PackageVersion
    
    # save
    sc $TaskGroupFilePath -Value (ConvertTo-Pson -InputObject $TaskGroup -Depth 12 -Layers 12 -Strict) -Force
}

function Set-TaskParameter(
[string]
[ValidateNotNullOrEmpty()]
[Parameter(
    Mandatory=$true,
    ValueFromPipelineByPropertyName=$true)]
$TaskGroupName,

[string]
[ValidateNotNullOrEmpty()]
[Parameter(
    Mandatory=$true,
    ValueFromPipelineByPropertyName=$true)]
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
    
    $TaskGroupFilePath = "$ProjectRootDirPath\.PoshDevOps\$TaskGroupName.psd1"
    
    # fetch task group
    $TaskGroup = Get-TaskGroup -Name $TaskGroupName -ProjectRootDirPath $ProjectRootDirPath

    # fetch task
    $Task = $TaskGroup.Tasks.$TaskName

    # handle task not found
    if(!$Task){
throw `
@"
Task "$TaskName" not found in task group "$TaskGroupName"
for project "$(Resolve-Path $ProjectRootDirPath)".
"@
    }

    # handle the case where this is the first parameter set
    If(!$Task.Parameters){
        $Task.Parameters = @{$Name=$Value}
    }
    # guard against unintentionally overwriting existing parameter value
    ElseIf(!$Force.IsPresent -and ($Task.Parameters.$Name)){
throw `
@"
A value of $($Task.Parameters.$Name) has already been set for parameter $Name in task "$TaskName" in task group "$TaskGroupName"
for project "$(Resolve-Path $ProjectRootDirPath)".

If you want to overwrite the existing parameter value use the -Force parameter
"@
    }
    Else{    
        $Task.Parameters.$Name = $Value
    }
    
    # save
    sc $TaskGroupFilePath -Value (ConvertTo-Pson -InputObject $TaskGroup -Depth 12 -Layers 12 -Strict) -Force
}

# task group operations
Export-ModuleMember -Function Get-TaskGroup
Export-ModuleMember -Function Add-TaskGroup
Export-ModuleMember -Function Rename-TaskGroup
Export-ModuleMember -Function Remove-TaskGroup

# task operations
Export-ModuleMember -Function Add-Task
Export-ModuleMember -Function Remove-Task
Export-ModuleMember -Function Rename-Task
Export-ModuleMember -Function Update-TaskPackageVersion
Export-ModuleMember -Function Set-TaskParameter