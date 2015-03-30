Import-Module "$PSScriptRoot\..\OrderedDictionaryExtensions"
Import-Module "$PSScriptRoot\..\Pson"

function Get-DevOp(

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
        an internal utility function that retrieves a DevOp from storage
    #>

    $DevOpFilePath = Resolve-Path "$ProjectRootDirPath\.Appease\$Name.psd1"   
    Write-Output (Get-Content $DevOpFilePath | Out-String | ConvertFrom-Pson)

}

function Add-DevOp(
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
        an internal utility function that saves a DevOp to storage
    #>

    $DevOpFilePath = "$ProjectRootDirPath\.Appease\$($Value.Name).psd1"

    # guard against unintentionally overwriting existing DevOp
    if(!$Force.IsPresent -and (Test-Path $DevOpFilePath)){
throw `
@"
Task group "$($Value.Name)" already exists
for project "$(Resolve-Path $ProjectRootDirPath)".

Task group names must be unique.
If you want to overwrite the existing DevOp use the -Force parameter
"@
    }

Write-Debug `
@"
Creating DevOp file at:
$DevOpFilePath
Creating...
"@

    New-Item -Path $DevOpFilePath -ItemType File -Force        
    Set-Content $DevOpFilePath -Value (ConvertTo-Pson -InputObject $Value -Depth 12 -Layers 12 -Strict) -Force
    
}



function Rename-DevOp(
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
        an internal utility function that updates the name of a DevOp in storage
    #>
    
    $OldDevOpFilePath = "$ProjectRootDirPath\.Appease\$OldName.psd1"
    $NewDevOpFilePath = "$ProjectRootDirPath\.Appease\$NewName.psd1"

    # guard against unintentionally overwriting existing DevOp
    if(!$Force.IsPresent -and (Test-Path $NewDevOpFilePath)){
throw `
@"
Task group "$NewName" already exists
for project "$(Resolve-Path $ProjectRootDirPath)".

Task group names must be unique.
If you want to overwrite the existing DevOp use the -Force parameter
"@
    }

    # fetch DevOp
    $DevOp = Get-DevOp -Name $OldName -ProjectRootDirPath $ProjectRootDirPath

    # update name
    $DevOp.Name = $NewName

        
    #save
    mv $OldDevOpFilePath $NewDevOpFilePath -Force
    sc $NewDevOpFilePath -Value (ConvertTo-Pson -InputObject $DevOp -Depth 12 -Layers 12 -Strict) -Force
}

function Remove-DevOp(

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
        an internal utility function that removes a DevOp from storage
    #>
    
    $DevOpFilePath = Resolve-Path "$ProjectRootDirPath\.Appease\$Name.psd1"
    
    Remove-Item -Path $DevOpFilePath -Force
}

function Add-DevOpTask(
[string]
[ValidateNotNullOrEmpty()]
[Parameter(
    Mandatory=$true,
    ValueFromPipelineByPropertyName=$true)]
$DevOpName,

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
        an internal utility function that adds a task to a DevOp in storage
    #>    
    
    $DevOpFilePath = "$ProjectRootDirPath\.Appease\$DevOpName.psd1"

    # fetch DevOp
    $DevOp = Get-DevOp -Name $DevOpName -ProjectRootDirPath $ProjectRootDirPath

    # guard against unintentionally overwriting existing tasks
    if(!$Force.IsPresent -and ($DevOp.Tasks.$Name)){
throw `
@"
Task "$Name" already exists in DevOp "$DevOpName"
for project "$(Resolve-Path $ProjectRootDirPath)".

Task names must be unique.
If you want to overwrite the existing task use the -Force parameter
"@
    }

    # construct task object
    $Task = @{Name=$Name;PackageId=$PackageId;PackageVersion=$PackageVersion;}

    # add task to taskgroup
    $DevOp.Tasks.Insert($Index,$Name,$Task)

    # save
    sc $DevOpFilePath -Value (ConvertTo-Pson -InputObject $DevOp -Depth 12 -Layers 12 -Strict) -Force
}

function Remove-DevOpTask(
[string]
[ValidateNotNullOrEmpty()]
[Parameter(
    Mandatory=$true,
    ValueFromPipelineByPropertyName=$true)]
$DevOpName,

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
    
    $DevOpFilePath = "$ProjectRootDirPath\.Appease\$DevOpName.psd1"
    
    # fetch DevOp
    $DevOp = Get-DevOp -Name $DevOpName -ProjectRootDirPath $ProjectRootDirPath

    # remove task
    $DevOp.Tasks.Remove($Name)

    # save
    sc $DevOpFilePath -Value (ConvertTo-Pson -InputObject $DevOp -Depth 12 -Layers 12 -Strict) -Force
}

function Rename-DevOpTask(
[string]
[ValidateNotNullOrEmpty()]
[Parameter(
    Mandatory=$true,
    ValueFromPipelineByPropertyName=$true)]
$DevOpName,

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
    
    $DevOpFilePath = "$ProjectRootDirPath\.Appease\$DevOpName.psd1"
    
    # fetch DevOp
    $DevOp = Get-DevOp -Name $DevOpName -ProjectRootDirPath $ProjectRootDirPath

    # fetch task
    $Task = $DevOp.Tasks.$OldName

    # handle task not found
    if(!$Task){
throw `
@"
Task "$TaskName" not found in DevOp "$DevOpName"
for project "$(Resolve-Path $ProjectRootDirPath)".
"@
    }

    # guard against unintentionally overwriting existing task
    if(!$Force.IsPresent -and ($DevOp.Tasks.$NewName)){
throw `
@"
Task "$NewName" already exists in DevOp "$DevOpName"
for project "$(Resolve-Path $ProjectRootDirPath)".

Task names must be unique.
If you want to overwrite the existing task use the -Force parameter
"@
    }

    # get task index
    $Index = Get-IndexOfKeyInOrderedDictionary -Key $OldName -OrderedDictionary $DevOp.Tasks

    # update name
    $Task.Name = $NewName

    # remove old record
    $DevOp.Tasks.Remove($OldName)

    # insert new record
    $DevOp.Tasks.Insert($Index,$Task.Name,$Task)

    # save
    sc $DevOpFilePath -Value (ConvertTo-Pson -InputObject $DevOp -Depth 12 -Layers 12 -Strict) -Force
}

function Set-DevOpTaskParameter(
[string]
[ValidateNotNullOrEmpty()]
[Parameter(
    Mandatory=$true,
    ValueFromPipelineByPropertyName=$true)]
$DevOpName,

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
    
    $DevOpFilePath = "$ProjectRootDirPath\.Appease\$DevOpName.psd1"
    
    # fetch DevOp
    $DevOp = Get-DevOp -Name $DevOpName -ProjectRootDirPath $ProjectRootDirPath

    # fetch task
    $Task = $DevOp.Tasks.$TaskName

    # handle task not found
    if(!$Task){
throw `
@"
Task "$TaskName" not found in DevOp "$DevOpName"
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
A value of $($Task.Parameters.$Name) has already been set for parameter $Name in task "$TaskName" in DevOp "$DevOpName"
for project "$(Resolve-Path $ProjectRootDirPath)".

If you want to overwrite the existing parameter value use the -Force parameter
"@
    }
    Else{    
        $Task.Parameters.$Name = $Value
    }
    
    # save
    sc $DevOpFilePath -Value (ConvertTo-Pson -InputObject $DevOp -Depth 12 -Layers 12 -Strict) -Force
}

function Update-DevOpTaskPackageVersion(
[string]
[ValidateNotNullOrEmpty()]
[Parameter(
    Mandatory=$true,
    ValueFromPipelineByPropertyName=$true)]
$DevOpName,

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
    
    $DevOpFilePath = "$ProjectRootDirPath\.Appease\$DevOpName.psd1"
    
    # fetch DevOp
    $DevOp = Get-DevOp -Name $DevOpName -ProjectRootDirPath $ProjectRootDirPath

    # fetch task
    $Task = $DevOp.Tasks.$TaskName

    # handle task not found
    if(!$Task){
throw `
@"
Task "$TaskName" not found in DevOp "$DevOpName"
for project "$(Resolve-Path $ProjectRootDirPath)".
"@
    }

    # update task version
    $Task.PackageVersion = $PackageVersion
    
    # save
    sc $DevOpFilePath -Value (ConvertTo-Pson -InputObject $DevOp -Depth 12 -Layers 12 -Strict) -Force
}

Export-ModuleMember -Function @(
                    # DevOp API
                    'Get-DevOp',
                    'Add-DevOp',
                    'Rename-DevOp',
                    'Remove-DevOp',
                    # DevOp Task API
                    'Add-DevOpTask',
                    'Remove-DevOpTask',
                    'Rename-DevOpTask',
                    'Set-DevOpTaskParameter',
                    'Update-DevOpTaskPackageVersion')
