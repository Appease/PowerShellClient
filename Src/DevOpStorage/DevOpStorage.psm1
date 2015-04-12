function Get-AppeaseDevOpDirPath(

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
        An Internal utility function that returns the dir path of a devop
    #>

    Write-Output "$ProjectRootDirPath\.Appease\DevOps\$Name"
}

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

   $DevOpDirPath = Get-AppeaseDevOpDirPath -Name $Name -ProjectRootDirPath $ProjectRootDirPath
   Write-Output "$DevOpDirPath\$Name.json"
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

    $OldDevOpDirPath = Get-AppeaseDevOpDirPath -Name $OldName -ProjectRootDirPath $ProjectRootDirPath
    $NewDevOpDirPath = Get-AppeaseDevOpDirPath -Name $NewName -ProjectRootDirPath $ProjectRootDirPath
        
    mv $OldDevOpDirPath $NewDevOpDirPath -Force:$Force
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
    $ConfigurationName,

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

    # fetch configuration
    $Configuration = Get-AppeaseConfiguration -Name $ConfigurationName -DevOpName $DevOpName -ProjectRootDirPath $ProjectRootDirPath
    
    # handle first task parameter value mapped
    if(!$Configuration.TaskParameters.$TaskName){
        $Configuration.TaskParameters.$TaskName = @{}
    }

    foreach($TaskParameterEntry in $TaskParameter.GetEnumerator()){
        $ParameterName = $TaskParameterEntry.Key
        $ParameterValue = $TaskParameterEntry.Value
        # guard against unintentionally overwriting existing parameter value
        If(!$Force.IsPresent -and ($Configuration.TaskParameters.$TaskName.$ParameterName)){
throw `
@"
A value of '$($Configuration.TaskParameters.$TaskName.$ParameterName)' has already been set for configuration '$ConfigurationName' 
of devop '$DevOpName' task '$TaskName' parameter '$ParameterName'
in project '$(Resolve-Path $ProjectRootDirPath)'.

If you want to overwrite the existing parameter value use the -Force parameter
"@
        }
        Else{    
            $Configuration.TaskParameters.$TaskName.$ParameterName = $ParameterValue
        }
    }
        
    # build up Save-AppeaseConfiguration parameters
    $SaveAppeaseConfigurationParameters = @{
        Name=$ConfigurationName;
        DevOpName=$DevOpName;
        TaskParameter=$Configuration.TaskParameters;
        ProjectRootDirPath=$ProjectRootDirPath
    }
    if($Configuration.ParentName){
        $SaveAppeaseConfigurationParameters.ParentName = $Configuration.ParentName
    }

    # save
    [PSCustomObject]$SaveAppeaseConfigurationParameters | Save-AppeaseConfiguration
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

function Get-AppeaseConfigurationFilePath(
    
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

    Write-Output "$ProjectRootDirPath\.Appease\DevOps\$DevOpName\Configurations\$Name.json"
}

function Save-AppeaseConfiguration(
    
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
    $Variable = @{},
    
    [Hashtable]
    [ValidateNotNull()]
    [Parameter(
        ValueFromPipelineByPropertyName=$true)]
    $TaskParameter = @{},

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
    
    $ConfigurationFilePath = Get-AppeaseConfigurationFilePath  -Name $Name -DevOpName $DevOpName -ProjectRootDirPath $ProjectRootDirPath

    if(!(Test-Path -Path $ConfigurationFilePath)){
        New-Item -ItemType File -Path $ConfigurationFilePath -Force
    }

    $Configuration = @{
        Variables = $Variable;
        TaskParameters = $TaskParameter
    }

    if($ParentName){
        $Configuration.ParentName = $ParentName
    }

    Set-Content $ConfigurationFilePath -Value (ConvertTo-Json -InputObject $Configuration -Depth 12) -Force
}

function Add-AppeaseConfiguration(
    
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
        Creates a new configuration
    #>

    $ConfigurationFilePath = Get-AppeaseConfigurationFilePath -Name $Name -DevOpName $DevOpName -ProjectRootDirPath $ProjectRootDirPath

    If(!$Force.IsPresent -and (Test-Path $ConfigurationFilePath)){
throw `
@"
configuration "$Name" already exists
for project "$(Resolve-Path $ProjectRootDirPath)".

configuration names must be unique.
If you want to overwrite the existing configuration use the -Force parameter
"@
    }Else{

        Save-AppeaseConfiguration -Name $Name -DevOpName $DevOpName -ProjectRootDirPath $ProjectRootDirPath
    }
}

function Get-AppeaseConfiguration(

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
        Retrieves a configuration from storage
    #>

    $ConfigurationFilePath = Get-AppeaseConfigurationFilePath -Name $Name -DevOpName $DevOpName -ProjectRootDirPath $ProjectRootDirPath
    
    $Configuration = Get-Content $ConfigurationFilePath | Out-String | ConvertFrom-Json

    # Convert the Variables property from a PSCustomObject to a Hashtable
    $VariablesHashtable = @{}
    $Configuration.Variables.PSObject.Properties | %{$VariablesHashtable[$_.Name] = $_.Value}
    $Configuration.Variables = $VariablesHashtable 
    
    # Convert the TaskParameters property from a PSCustomObject of PSCustomObjects to a Hashtable of Hashtables
    $TaskParametersHashtable = @{}
    foreach($TaskParameter in $Configuration.TaskParameters.PSObject.Properties)
    {
        $TaskName = $TaskParameter.Name
        $TaskParametersHashtable.$TaskName = @{}
        $Configuration.TaskParameters.$TaskName.PSObject.Properties | %{$TaskParametersHashtable.$TaskName[$_.Name] = $_.Value}
    }
    $Configuration.TaskParameters = $TaskParametersHashtable
    
    Write-Output $Configuration

}

function Set-AppeaseConfigurationParentName(

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
    $Configuration = Get-AppeaseConfiguration -Name $Name -DevOpName $DevOpName -ProjectRootDirPath $ProjectRootDirPath

    # build up Save-AppeaseConfiguration parameters
    $SaveAppeaseConfigurationParameters = @{
        Name = $ConfigurationName;
        DevOpName = $DevOpName;
        ParentName = $ParentName;
        ProjectRootDirPath = $ProjectRootDirPath
    }

    if($Configuration.Variables){
        $SaveAppeaseConfigurationParameters.Variable = $Configuration.Variables
    }

    if($Configuration.TaskParameters){
        $SaveAppeaseConfigurationParameters.TaskParameter = $Configuration.TaskParameters
    }

    [PSCustomObject]$SaveAppeaseConfigurationParameters | Save-AppeaseConfiguration
}

function Set-AppeaseConfigurationVariable(

    [string]
    [ValidateNotNullOrEmpty()]
    [Parameter(
        Mandatory=$true,
        ValueFromPipelineByPropertyName=$true)]
    $Name,

    [PSCustomObject]
    [ValidateNotNullOrEmpty()]
    [Parameter(
        Mandatory=$true,
        ValueFromPipelineByPropertyName=$true)]
    $Value,

    [string]    
    [ValidateNotNullOrEmpty()]
    [Parameter(
        Mandatory=$true,
        ValueFromPipelineByPropertyName=$true)]
    $ConfigurationName,

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
    
    $Configuration = Get-AppeaseConfiguration -Name $ConfigurationName -DevOpName $DevOpName -ProjectRootDirPath $ProjectRootDirPath

    $Configuration.Variables.$Name = $Value

    # build up Save-AppeaseConfiguration parameters
    $SaveAppeaseConfigurationParameters = @{
        Name = $ConfigurationName;
        DevOpName = $DevOpName;
        Variable = $Configuration.Variables;
        ProjectRootDirPath = $ProjectRootDirPath
    }

    if($Configuration.TaskParameters){
        $SaveAppeaseConfigurationParameters.TaskParameter = $Configuration.TaskParameters
    }

    if($Configuration.ParentName){
        $SaveAppeaseConfigurationParameters.ParentName = $Configuration.ParentName
    }

    [PSCustomObject]$SaveAppeaseConfigurationParameters | Save-AppeaseConfiguration

}

function Remove-AppeaseConfigurationVariable(

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
    $ConfigurationName,

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

    Get-AppeaseConfiguration -Name $ConfigurationName -DevOpName $DevOpName -ProjectRootDirPath $ProjectRootDirPath

    $Configuration.Variables.Remove($Name)

    # build up Save-AppeaseConfiguration parameters
    $SaveAppeaseConfigurationParameters = @{
        Name = $ConfigurationName;
        DevOpName = $DevOpName;
        ProjectRootDirPath = $ProjectRootDirPath
    }

    if($Configuration.Variables){
        $SaveAppeaseConfigurationParameters.Variable = $Configuration.Variables
    }

    if($Configuration.TaskParameters){
        $SaveAppeaseConfigurationParameters.TaskParameter = $Configuration.TaskParameters
    }

    if($Configuration.ParentName){
        $SaveAppeaseConfigurationParameters.ParentName = $Configuration.ParentName
    }

    [PSCustomObject]$SaveAppeaseConfigurationParameters | Save-AppeaseConfiguration

}

function Rename-AppeaseConfiguration(

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
        Updates the name of a configuration in storage
    #>
        
    $OldConfigurationFilePath = Get-AppeaseConfigurationFilePath -Name $OldName -DevOpName $DevOpName -ProjectRootDirPath $ProjectRootDirPath
    $NewConfigurationFilePath = Get-AppeaseConfigurationFilePath -Name $NewName -DevOpName $DevOpName -ProjectRootDirPath $ProjectRootDirPath

    mv $OldConfigurationFilePath $NewConfigurationFilePath -Force:$Force

}

function Remove-AppeaseConfiguration(

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
        Removes a configuration from storage
    #>
    
    $ConfigurationFilePath = Get-AppeaseConfigurationFilePath -Name $Name -DevOpName $DevOpName -ProjectRootDirPath $ProjectRootDirPath
    
    Remove-Item -Path $ConfigurationFilePath -Force
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
                    
                    # Configuration API
                    'Add-AppeaseConfiguration',
                    'Get-AppeaseConfiguration',
                    'Set-AppeaseConfigurationParentName',
                    'Set-AppeaseConfigurationVariable',
                    'Remove-AppeaseConfigurationVariable',
                    'Rename-AppeaseConfiguration',
                    'Remove-AppeaseConfiguration')
