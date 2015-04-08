function Get-AppeaseDevOpFilePath(

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
    $ProjectRootDirPath = '.'

){
    <#
        .Synopsis
        An Internal utility function that returns the file path of a devop
    #>

    Write-Output "$ProjectRootDirPath\.Appease\DevOps\$Name\$Name.json"
}

function Save-AppeaseDevOp(

    [string]
    [ValidateNotNullOrEmpty()]
    [Parameter(
        Mandatory=$true,
        ValueFromPipelineByPropertyName=$true)]
    $Name,

    [PSCustomObject[]]
    [ValidateNotNull()]
    [Parameter(
        ValueFromPipelineByPropertyName=$true)]
    $Task = @(),

    [string]
    [ValidateScript({Test-Path $_ -PathType Container})]
    [Parameter(
        ValueFromPipelineByPropertyName=$true)]
    $ProjectRootDirPath = '.'
){
    <#
        .Synopsis
        An Internal utility function that saves a devop to disk
    #>
    
    $DevOpFilePath = Get-AppeaseDevOpFilePath -Name $Name -ProjectRootDirPath $ProjectRootDirPath

    if(!(Test-Path -Path $DevOpFilePath)){
        New-Item -ItemType File -Path $DevOpFilePath -Force
    }

    $DevOp = @{Tasks=$Task}

    Set-Content $DevOpFilePath -Value (ConvertTo-Json -InputObject $DevOp -Depth 12) -Force
}

function New-AppeaseDevOp(

    [string]
    [ValidateNotNullOrEmpty()]
    [Parameter(
        Mandatory=$true,
        ValueFromPipelineByPropertyName=$true)]
    $Name,

    [switch]
    [Parameter(
        ValueFromPipelineByPropertyName=$true)]
    $Force,

    [string]
    [ValidateScript({Test-Path $_ -PathType Container})]
    [Parameter(
        ValueFromPipelineByPropertyName=$true)]
    $ProjectRootDirPath = '.'

){
    <#
        .Synopsis
        creates a new devop
    #>

    $DevOpFilePath = Get-AppeaseDevOpFilePath -Name $Name -ProjectRootDirPath $ProjectRootDirPath

    If(!$Force.IsPresent -and (Test-Path $DevOpFilePath)){
throw `
@"
dev op "$($Name)" already exists
for project "$(Resolve-Path $ProjectRootDirPath)".

dev op names must be unique.
If you want to overwrite the existing dev op use the -Force parameter
"@
    }Else{

        Save-AppeaseDevOp -Name $Name -ProjectRootDirPath $ProjectRootDirPath
    }
}

function Get-AppeaseDevOp(

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
    $ProjectRootDirPath = '.'

){
    <#
        .SYNOPSIS
        an internal utility function that retrieves a DevOp from storage
    #>

    $DevOpFilePath = Get-AppeaseDevOpFilePath -Name $Name -ProjectRootDirPath $ProjectRootDirPath
    
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
    $ProjectRootDirPath = '.'

){
    <#
        .SYNOPSIS
        an internal utility function that updates the name of a DevOp in storage
    #>

    $OldDevOpFilePath = Get-AppeaseDevOpFilePath -Name $OldName -ProjectRootDirPath $ProjectRootDirPath
    $NewDevOpFilePath = Get-AppeaseDevOpFilePath -Name $NewName -ProjectRootDirPath $ProjectRootDirPath
        
    mv $OldDevOpFilePath $NewDevOpFilePath -Force:$Force
}

function Remove-AppeaseDevOp(

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
    $ProjectRootDirPath = '.'

){
    <#
        .SYNOPSIS
        Removes a DevOp from storage
    #>
    
    $ConfirmationPromptQuery = "Are you sure you want to remove devop '$Name'?"
    $ConfirmationPromptCaption = 'Confirm Task removal'

    if($Force.IsPresent -or $PSCmdlet.ShouldContinue($ConfirmationPromptQuery,$ConfirmationPromptCaption)){
            
        $DevOpFilePath = Get-AppeaseDevOpFilePath -Name $Name -ProjectRootDirPath $ProjectRootDirPath    
        Remove-Item -Path $DevOpFilePath -Force

    }
}

function Get-AppeaseDevOpTasks(
 
    [string]
    [ValidateNotNullOrEmpty()]
    [Parameter(
        Mandatory=$true,
        ValueFromPipelineByPropertyName=$true)]
    $DevOpName,

    [string]
    [ValidateScript({Test-Path $_ -PathType Container})]
    [Parameter(
        ValueFromPipelineByPropertyName=$true)]
    $ProjectRootDirPath = '.'

){
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
    $ProjectRootDirPath = '.'

){
    <#
        .SYNOPSIS
        an internal utility function that adds a task to a DevOp in storage
    #>    
    
    # fetch DevOp
    $Tasks = Get-AppeaseDevOp -Name $DevOpName -ProjectRootDirPath $ProjectRootDirPath | Select -ExpandProperty Tasks

    # if this is first task
    If(!$Tasks){
        $Tasks = {@()}.Invoke()
    }

    # guard against unintentionally overwriting existing tasks
    if(!$Force.IsPresent -and ($Tasks|?{$_.Name -eq $Name})){
throw `
@"
Task '$Name' already exists in devop '$DevOpName'
for project '$(Resolve-Path $ProjectRootDirPath)'.

Task names must be unique.
If you want to overwrite the existing task use the -Force parameter
"@
    }

    # construct task object
    $Task = @{Name=$Name;TemplateId=$TemplateId;TemplateVersion=$TemplateVersion}

    # add task to dev op 
    $Tasks.Insert($Index,$Task)

    # save
    Save-AppeaseDevOp -Name $DevOpName -Task $Tasks -ProjectRootDirPath $ProjectRootDirPath

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
    $ProjectRootDirPath = '.'

){
    $ConfirmationPromptQuery = "Are you sure you want to remove the Task with name $Name`?"
    $ConfirmationPromptCaption = 'Confirm Task removal'

    if($Force.IsPresent -or $PSCmdlet.ShouldContinue($ConfirmationPromptQuery,$ConfirmationPromptCaption)){

        # fetch tasks
        $Tasks = Get-AppeaseDevOp -Name $DevOpName -ProjectRootDirPath $ProjectRootDirPath | Select -ExpandProperty Tasks

        # remove task
        $Tasks.Remove(($Tasks|?{$_.Name -eq $Name}))

        # save
        Save-AppeaseDevOp -Name $DevOpName -Task $Tasks -ProjectRootDirPath $ProjectRootDirPath

    }   

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
    $ProjectRootDirPath = '.'

){
        
    # fetch devop
    $Tasks = Get-AppeaseDevOp -Name $DevOpName -ProjectRootDirPath $ProjectRootDirPath | Select -ExpandProperty Tasks

    # fetch task
    $Task = $Tasks|?{$_.Name -eq $OldName}

    # handle task not found
    if(!$Task){
throw `
@"
Task '$TaskName' not found in dev op '$DevOpName'
for project '$(Resolve-Path $ProjectRootDirPath)'.
"@
    }

    # guard against unintentionally overwriting existing task
    if(!$Force.IsPresent -and ($Tasks|?{$_.Name -eq $NewName})){
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
    Save-AppeaseDevOp -Name $DevOpName -Task $Tasks -ProjectRootDirPath $ProjectRootDirPath

}

function Set-AppeaseTaskParameter(
    
    [string]
    [ValidateNotNullOrEmpty()]
    [Parameter(
        Mandatory=$true,
        ValueFromPipelineByPropertyName=$true)]
    $ParameterSetName,

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

    [Hashtable]
    [ValidateNotNullOrEmpty()]
    [ValidateCount(1,[int]::MaxValue)]
    [Parameter(
        Mandatory=$true)]
    $TaskParameter,

    [switch]
    $Force,

    [string]
    [ValidateScript({Test-Path $_ -PathType Container})]
    [Parameter(
        ValueFromPipelineByPropertyName=$true)]
    $ProjectRootDirPath = '.'

){

    # fetch devop
    $DevOp = Get-AppeaseDevOp -Name $DevOpName -ProjectRootDirPath $ProjectRootDirPath
    
    # handle task not found
    if(!($DevOp.Tasks|?{$_.Name -eq $TaskName})){
throw `
@"
Task '$TaskName' not found in devop '$DevOpName'
for project '$(Resolve-Path $ProjectRootDirPath)'.
"@
    }

    # fetch parameter set
    $ParameterSet = Get-AppeaseParameterSet -Name $ParameterSetName -DevOpName $DevOpName -ProjectRootDirPath $ProjectRootDirPath
    
    # handle first task parameter value mapped
    if(!$ParameterSet.Mappings.$TaskName){
        $ParameterSet.Mappings.$TaskName = @{}
    }

    foreach($TaskParameterEntry in $TaskParameter.GetEnumerator()){
        $ParameterName = $TaskParameterEntry.Key
        $ParameterValue = $TaskParameterEntry.Value
        # guard against unintentionally overwriting existing parameter value
        If(!$Force.IsPresent -and ($ParameterSet.Mappings.$TaskName.$ParameterName)){
throw `
@"
A value of '$($ParameterSet.Mappings.$TaskName.$ParameterName)' has already been set for configuration '$ParameterSetName' 
of devop '$DevOpName' task '$TaskName' parameter '$ParameterName'
in project '$(Resolve-Path $ProjectRootDirPath)'.

If you want to overwrite the existing parameter value use the -Force parameter
"@
        }
        Else{    
            $ParameterSet.Mappings.$TaskName.$ParameterName = $ParameterValue
        }
    }
        
    # build up Save-AppeaseParameterSet parameters
    $SaveAppeaseParameterSetParameters = @{
        Name=$ParameterSetName;
        DevOpName=$DevOpName;
        Mapping=$ParameterSet.Mappings;
        ProjectRootDirPath=$ProjectRootDirPath
    }
    if($ParameterSet.ParentName){
        $SaveAppeaseParameterSetParameters.ParentName = $ParameterSet.ParentName
    }

    # save
    [PSCustomObject]$SaveAppeaseParameterSetParameters | Save-AppeaseParameterSet
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
    $ProjectRootDirPath = '.'

){
        
    # get tasks from file
    $Tasks = Get-AppeaseDevOp -Name $DevOpName -ProjectRootDirPath $ProjectRootDirPath | Select -ExpandProperty Tasks

    # fetch task
    $Task = $Tasks|?{$_.Name -eq $TaskName}

    # handle task not found
    if(!$Task){
throw `
@"
Task '$TaskName' not found in devop '$DevOpName'
for project '$(Resolve-Path $ProjectRootDirPath)'.
"@
    }

    # update task version
    $Task.TemplateVersion = $TemplateVersion
    
    # save to file
    Save-AppeaseDevOp -Name $DevOpName -Task $Tasks -ProjectRootDirPath $ProjectRootDirPath

}

function Get-AppeaseParameterSetFilePath(
    
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
    $DevOpName,

    [string]
    [ValidateScript({Test-Path $_ -PathType Container})]
    [Parameter(
        ValueFromPipelineByPropertyName=$true)]
    $ProjectRootDirPath = '.'

){
    <#
        .Synopsis
        An Internal utility function that returns the file path of a devop configuration
    #>

    Write-Output "$ProjectRootDirPath\.Appease\DevOps\$DevOpName\ParameterSets\$Name.json"
}

function Save-AppeaseParameterSet(
    
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
    $DevOpName,
    
    [Hashtable]
    [ValidateNotNull()]
    [Parameter(
        ValueFromPipelineByPropertyName=$true)]
    $Mapping = @{},

    [string]
    [ValidateNotNullOrEmpty()]
    [Parameter(
        ValueFromPipelineByPropertyName=$true)]
    $ParentName,

    [string]
    [ValidateScript({Test-Path $_ -PathType Container})]
    [Parameter(
        ValueFromPipelineByPropertyName=$true)]
    $ProjectRootDirPath = '.'

){
    <#
        .Synopsis
        An Internal utility function that saves a devop configuration to disk
    #>
    
    $ParameterSetFilePath = Get-AppeaseParameterSetFilePath  -Name $Name -DevOpName $DevOpName -ProjectRootDirPath $ProjectRootDirPath

    if(!(Test-Path -Path $ParameterSetFilePath)){
        New-Item -ItemType File -Path $ParameterSetFilePath -Force
    }

    $ParameterSet = @{Mappings= $Mapping}

    if($ParentName){
        $ParameterSet.ParentName = $ParentName
    }

    Set-Content $ParameterSetFilePath -Value (ConvertTo-Json -InputObject $ParameterSet -Depth 12) -Force
}

function Add-AppeaseParameterSet(
    
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
    $DevOpName,

    [switch]
    [Parameter(
        ValueFromPipelineByPropertyName=$true)]
    $Force,

    [string]
    [ValidateScript({Test-Path $_ -PathType Container})]
    [Parameter(
        ValueFromPipelineByPropertyName=$true)]
    $ProjectRootDirPath = '.'

){
    <#
        .Synopsis
        Creates a new parameter set
    #>

    $ParameterSetFilePath = Get-AppeaseParameterSetFilePath -Name $Name -DevOpName $DevOpName -ProjectRootDirPath $ProjectRootDirPath

    If(!$Force.IsPresent -and (Test-Path $ParameterSetFilePath)){
throw `
@"
configuration "$Name" already exists
for project "$(Resolve-Path $ProjectRootDirPath)".

configuration names must be unique.
If you want to overwrite the existing configuration use the -Force parameter
"@
    }Else{

        Save-AppeaseParameterSet -Name $Name -DevOpName $DevOpName -ProjectRootDirPath $ProjectRootDirPath
    }
}

function Get-AppeaseParameterSet(

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
    $DevOpName,

    [string]
    [ValidateScript({Test-Path $_ -PathType Container})]
    [Parameter(
        ValueFromPipelineByPropertyName=$true)]
    $ProjectRootDirPath = '.'

){
    <#
        .SYNOPSIS
        Retrieves a parameter set from storage
    #>

    $ParameterSetFilePath = Get-AppeaseParameterSetFilePath -Name $Name -DevOpName $DevOpName -ProjectRootDirPath $ProjectRootDirPath
    
    $ParameterSet = Get-Content $ParameterSetFilePath | Out-String | ConvertFrom-Json
    
    # Convert the mappings property from a PSCustomObject of PSCustomObjects to a Hashtable of Hashtables
    $MappingsHashtable = @{}
    foreach($Mapping in $ParameterSet.Mappings.PSObject.Properties)
    {
        $TaskName = $Mapping.Name
        $MappingsHashtable.$TaskName = @{}
        $ParameterSet.Mappings.$TaskName.PSObject.Properties | %{$MappingsHashtable.$TaskName[$_.Name] = $_.Value}
    }

    $ParameterSet.Mappings = $MappingsHashtable
    
    Write-Output $ParameterSet

}

function Set-AppeaseParameterSetParentName(

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
    $ParentName,

    [string]
    [ValidateNotNullOrEmpty()]
    [Parameter(
        Mandatory=$true,
        ValueFromPipelineByPropertyName=$true)]
    $DevOpName,

    [string]
    [ValidateScript({Test-Path $_ -PathType Container})]
    [Parameter(
        ValueFromPipelineByPropertyName=$true)]
    $ProjectRootDirPath = '.'

){
    $ParameterSet = Get-AppeaseParameterSet -Name $Name -DevOpName $DevOpName -ProjectRootDirPath $ProjectRootDirPath
    Save-AppeaseParameterSet -Name $Name -DevOpName $DevOpName -Mapping $ParameterSet.Mappings -ParentName $ParentName -ProjectRootDirPath $ProjectRootDirPath
}

function Rename-AppeaseParameterSet(

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

    [string]
    [ValidateNotNullOrEmpty()]
    [Parameter(
        Mandatory=$true,
        ValueFromPipelineByPropertyName=$true)]
    $DevOpName,

    [string]
    [ValidateScript({Test-Path $_ -PathType Container})]
    [Parameter(
        ValueFromPipelineByPropertyName=$true)]
    $ProjectRootDirPath = '.',

    [switch]
    [Parameter(
        ValueFromPipelineByPropertyName=$true)]
    $Force

){
    <#
        .SYNOPSIS
        Updates the name of a parameter set in storage
    #>
        
    $OldParameterSetFilePath = Get-AppeaseParameterSetFilePath -Name $OldName -DevOpName $DevOpName -ProjectRootDirPath $ProjectRootDirPath
    $NewParameterSetFilePath = Get-AppeaseParameterSetFilePath -Name $NewName -DevOpName $DevOpName -ProjectRootDirPath $ProjectRootDirPath

    mv $OldParameterSetFilePath $NewParameterSetFilePath -Force:$Force

}

function Remove-AppeaseParameterSet(

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
    $DevOpName,

    [string]
    [ValidateScript({Test-Path $_ -PathType Container})]
    [Parameter(
        ValueFromPipelineByPropertyName=$true)]
    $ProjectRootDirPath = '.'
){
    <#
        .SYNOPSIS
        Removes a parameter set from storage
    #>
    
    $ParameterSetFilePath = Get-AppeaseParameterSetFilePath -Name $Name -DevOpName $DevOpName -ProjectRootDirPath $ProjectRootDirPath
    
    Remove-Item -Path $ParameterSetFilePath -Force
}

Export-ModuleMember -Function @(

                    # DevOp API
                    'New-AppeaseDevOp',
                    'Get-AppeaseDevOp',
                    'Rename-AppeaseDevOp',
                    'Remove-AppeaseDevOp',

                    # Task API
                    'Add-AppeaseTask',
                    'Remove-AppeaseTask',
                    'Rename-AppeaseTask',
                    'Set-AppeaseTaskParameter',
                    'Set-AppeaseTaskTemplateVersion'
                    
                    # ParameterSet API
                    'Add-AppeaseParameterSet',
                    'Get-AppeaseParameterSet',
                    'Set-AppeaseParameterSetParentName',
                    'Rename-AppeaseParameterSet',
                    'Remove-AppeaseParameterSet')
