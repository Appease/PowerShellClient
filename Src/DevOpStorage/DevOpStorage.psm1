function Save-AppeaseDevOpToFile(
[object]
$Value,

[switch]
$Force,

[string]
[ValidateScript({Test-Path $_ -PathType Container})]
[Parameter(
    ValueFromPipelineByPropertyName=$true)]
$ProjectRootDirPath = '.'){

    $DevOpFilePath = "$ProjectRootDirPath\.Appease\$($Value.Name).json"

    if(!$Force.IsPresent -and (Test-Path $DevOpFilePath)){
throw `
@"
dev op "$($Value.Name)" already exists
for project "$(Resolve-Path $ProjectRootDirPath)".

dev op names must be unique.
If you want to overwrite the existing dev op use the -Force parameter
"@
    }

    if(!(Test-Path -Path $DevOpFilePath)){
        New-Item -ItemType File -Path $DevOpFilePath -Force
    }

    Set-Content $DevOpFilePath -Value (ConvertTo-Json -InputObject $Value -Depth 12) -Force
}

Set-Alias -Name 'Add-AppeaseDevOp' -Value 'Save-AppeaseDevOpToFile'

function Get-AppeaseDevOpFromFile(

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

    $DevOpFilePath = Resolve-Path "$ProjectRootDirPath\.Appease\$Name.json"
    
    $DevOp = Get-Content $DevOpFilePath | Out-String | ConvertFrom-Json
    
    # convert tasks from Array to Collection
    $DevOp.Tasks = {$DevOp.Tasks}.Invoke()

    # convert task parameters from PSCustomObject to Hashtable
    # see : http://stackoverflow.com/questions/22002748/hashtables-from-convertfrom-json-have-different-type-from-powershells-built-in-h
    for($i = 0; $i -lt $DevOp.Tasks.Count; $i++)
    {
        if($DevOp.Tasks[$i].Parameters){
            $ParametersHashtable = @{}
            $DevOp.Tasks[$i].Parameters.PSObject.Properties | %{$ParametersHashtable[$_.Name] = $_.Value}
            $DevOp.Tasks[$i].Parameters = $ParametersHashtable
        }
    }

    Write-Output $DevOp

}

Set-Alias -Name 'Get-AppeaseDevOp' -Value 'Get-AppeaseDevOpFromFile'


function Rename-AppeaseDevOp(
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
        
    # fetch DevOp
    $DevOp = Get-AppeaseDevOpFromFile -Name $OldName -ProjectRootDirPath $ProjectRootDirPath

    # update name
    $DevOp.Name = $NewName

    # save to file with updated name
    Save-AppeaseDevOpToFile -Value $DevOp -Force:$Force -ProjectRootDirPath $ProjectRootDirPath
        
    #remove file with old name
    Remove-Item -Path "$ProjectRootDirPath\.Appease\$OldName.json" -Force

}

function Remove-AppeaseDevOp(

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
    
    $DevOpFilePath = Resolve-Path "$ProjectRootDirPath\.Appease\$Name.json"
    
    Remove-Item -Path $DevOpFilePath -Force
}

function Add-AppeaseTask(
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
$TemplateId,

[string]
[ValidateNotNullOrEmpty()]
[Parameter(
    Mandatory=$true,
    ValueFromPipelineByPropertyName=$true)]
$TemplateVersion,

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
    
    # fetch DevOp
    $DevOp = Get-AppeaseDevOpFromFile -Name $DevOpName -ProjectRootDirPath $ProjectRootDirPath

    # guard against unintentionally overwriting existing tasks
    if(!$Force.IsPresent -and ($DevOp.Tasks|?{$_.Name -eq $Name}|Select -First 1)){
throw `
@"
Task '$Name' already exists in DevOp '$DevOpName'
for project '$(Resolve-Path $ProjectRootDirPath)'.

Task names must be unique.
If you want to overwrite the existing task use the -Force parameter
"@
    }

    # construct task object
    $Task = @{Name=$Name;TemplateId=$TemplateId;TemplateVersion=$TemplateVersion}

    # add task to dev op 
    $DevOp.Tasks.Insert($Index,$Task)

    # save
    Save-AppeaseDevOpToFile -Value $DevOp -Force -ProjectRootDirPath $ProjectRootDirPath

}

function Remove-AppeaseTask(
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
        
    # fetch DevOp
    $DevOp = Get-AppeaseDevOpFromFile -Name $DevOpName -ProjectRootDirPath $ProjectRootDirPath

    # remove task
    $DevOp.Tasks.Remove(($DevOp.Tasks|?{$_.Name -eq $Name}|Select -First 1))

    # save
    Save-AppeaseDevOpToFile -Value $DevOp -Force -ProjectRootDirPath $ProjectRootDirPath

}

function Rename-AppeaseTask(
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
        
    # fetch DevOp
    $DevOp = Get-AppeaseDevOpFromFile -Name $DevOpName -ProjectRootDirPath $ProjectRootDirPath

    # fetch task
    $Task = $DevOp.Tasks|?{$_.Name -eq $OldName}|Select -First 1

    # handle task not found
    if(!$Task){
throw `
@"
Task '$TaskName' not found in dev op '$DevOpName'
for project '$(Resolve-Path $ProjectRootDirPath)'.
"@
    }

    # guard against unintentionally overwriting existing task
    if(!$Force.IsPresent -and ($DevOp.Tasks|?{$_.Name -eq $NewName}|Select -First 1)){
throw `
@"
Task '$NewName' already exists in dev op '$DevOpName'
for project '$(Resolve-Path $ProjectRootDirPath)'.

Task names must be unique.
If you want to overwrite the existing task use the -Force parameter
"@
    }

    # update name
    $Task.Name = $NewName

    # save
    Save-AppeaseDevOpToFile -Value $DevOp -Force -ProjectRootDirPath $ProjectRootDirPath

}

function Set-AppeaseTaskParameter(
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
           
    # fetch DevOp
    $DevOp = Get-AppeaseDevOpFromFile -Name $DevOpName -ProjectRootDirPath $ProjectRootDirPath

    # fetch task
    $Task = $DevOp.Tasks|?{$_.Name -eq $TaskName}|Select -First 1

    # handle task not found
    if(!$Task){
throw `
@"
Task '$TaskName' not found in DevOp '$DevOpName'
for project '$(Resolve-Path $ProjectRootDirPath)'.
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
A value of '$($Task.Parameters.$Name)' has already been set for parameter '$Name' of task '$TaskName' in DevOp '$DevOpName'
for project '$(Resolve-Path $ProjectRootDirPath)'.

If you want to overwrite the existing parameter value use the -Force parameter
"@
    }
    Else{    
        $Task.Parameters.$Name = $Value
    }
    
    # save
    Save-AppeaseDevOpToFile -Value $DevOp -Force -ProjectRootDirPath $ProjectRootDirPath
}

function Set-AppeaseTaskTemplateVersion(
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
$TemplateVersion,

[string]
[ValidateScript({Test-Path $_ -PathType Container})]
[Parameter(
    ValueFromPipelineByPropertyName=$true)]
$ProjectRootDirPath = '.'){
        
    # get from file
    $DevOp = Get-AppeaseDevOpFromFile -Name $DevOpName -ProjectRootDirPath $ProjectRootDirPath

    # fetch task
    $Task = $DevOp.Tasks|?{$_.Name -eq $TaskName}|Select -First 1

    # handle task not found
    if(!$Task){
throw `
@"
Task '$TaskName' not found in DevOp '$DevOpName'
for project '$(Resolve-Path $ProjectRootDirPath)'.
"@
    }

    # update task version
    $Task.TemplateVersion = $TemplateVersion
    
    # save to file
    Save-AppeaseDevOpToFile -Value $DevOp -Force -ProjectRootDirPath $ProjectRootDirPath

}


Export-ModuleMember -Alias @(
                    'Add-AppeaseDevOp',
                    'Get-AppeaseDevOp')

Export-ModuleMember -Function @(

                    # DevOp API
                    'Save-AppeaseDevOpToFile',
                    'Get-AppeaseDevOpFromFile',
                    'Add-AppeaseDevOp',
                    'Rename-AppeaseDevOp',
                    'Remove-AppeaseDevOp',

                    # Task API
                    'Add-AppeaseTask',
                    'Remove-AppeaseTask',
                    'Rename-AppeaseTask',
                    'Set-AppeaseTaskParameter',
                    'Set-AppeaseTaskTemplateVersion')
