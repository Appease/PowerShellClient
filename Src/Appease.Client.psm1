
function Invoke-AppeaseDevOp(

    [string]
    [ValidateNotNullOrEmpty()]
    [Parameter(
        Mandatory=$true,
        ValueFromPipelineByPropertyName=$true)]
    $Name,

    [string]
    [ValidateNotNullOrEmpty()]
    [Parameter(
        ValueFromPipelineByPropertyName=$true)]
    $ConfigurationName,

    [string[]]
    [ValidateCount( 1, [Int]::MaxValue)]
    [ValidateNotNullOrEmpty()]
    [Parameter(
        ValueFromPipelineByPropertyName=$true)]
    $TemplateSource = $DefaultTemplateSources,

    [String]
    [ValidateScript({Test-Path $_ -PathType Container})]
    [Parameter(
        ValueFromPipelineByPropertyName=$true)]
    $ProjectRootDirPath='.'

){    

    if($ConfigurationName){
        $Configuration = DevOpStorage\Get-AppeaseConfiguration -Name $ConfigurationName -DevOpName $Name -ProjectRootDirPath $ProjectRootDirPath        
    }
    
    # get devop
    $DevOp = DevOpStorage\Get-AppeaseDevOp -Name $Name -ProjectRootDirPath $ProjectRootDirPath

    foreach($Task in $DevOp.Tasks){
        $TaskName = $Task.Name

        # combine parameters
        $TaskParameters = $Configuration.TaskParameters.$TaskName
        # @todo: support default parameter values

        # add variables from configuration
        if($Configuration.Variables){
            $Variables = $Configuration.Variables          
        }
        else{
            $Variables = @{}
        }
        # add automatic variables
        $Variables.'Appease.ProjectRootDirPath' = (Resolve-Path $ProjectRootDirPath)
        $Variables.'Appease.Task.Name' = $TaskName
        # @todo: support composite variables (perform variable substitution on variables)

Write-Debug "Ensuring task template installed"
        TemplateManagement\Install-AppeaseTaskTemplate -Id $Task.TemplateId -Version $Task.TemplateVersion -Source $TemplateSource
        $TaskTemplateInstallDirPath = TemplateManagement\Get-AppeaseTaskTemplateInstallDirPath -Id $Task.TemplateId -Version $Task.TemplateVersion -ProjectRootDirPath $ProjectRootDirPath
        $TaskTemplateMetadata = TemplateManagement\Get-AppeaseTaskTemplateMetadata -TaskTemplateDirPath $TaskTemplateInstallDirPath

        # perform variable substitution on task parameters    
        $TaskInvocationCommand = $TaskTemplateMetadata.Invocation.Command
        foreach($TaskParameter in $TaskParameters.GetEnumerator()){
            foreach($Variable in $Variables.GetEnumerator()){
                $TaskParameter.Value = $TaskParameter.Value -creplace "#{$($Variable.Key)}",$Variable.Value
            }
            $TaskInvocationCommand += " -$($TaskParameter.Key) $($TaskParameter.Value)"
        }

        # invoke task template
        $OriginalLocation = Get-Location
        Try
        {
            Set-Location "$TaskTemplateInstallDirPath\bin"

Write-Debug `
@"
Invoking task '$TaskName' using command:
iex $TaskInvocationCommand
"@
        iex $TaskInvocationCommand

        }
        Finally{
            Set-Location $OriginalLocation
        }

    }
}

function Add-AppeaseTask(

    [CmdletBinding(
        DefaultParameterSetName="Add-AppeaseTaskLast")]

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
    $TemplateId,

    [string]
    [Parameter(
        ValueFromPipelineByPropertyName=$true)]
    $TemplateVersion,

    [string]
    [ValidateNotNullOrEmpty()]
    [Parameter(
        ValueFromPipelineByPropertyName=$true)]
    $Name = $TemplateId,

    [switch]
    [Parameter(
        Mandatory=$true,
        ValueFromPipelineByPropertyName=$true,
        ParameterSetName='Add-AppeaseTaskFirst')]
    $First,

    [string]
    [Parameter(
        Mandatory=$true,
        ValueFromPipelineByPropertyName=$true,
        ParameterSetName='Add-AppeaseTaskAfter')]
    $After,

    [string]
    [Parameter(
        Mandatory=$true,
        ValueFromPipelineByPropertyName=$true,
        ParameterSetName='Add-AppeaseTaskBefore')]
    $Before,

    [switch]
    [Parameter(
        ValueFromPipelineByPropertyName=$true,
        ParameterSetName='Add-AppeaseTaskLast')]
    $Last,

    [switch]
    [Parameter(
        ValueFromPipelineByPropertyName=$true)]
    $Force,

    [string[]]
    [ValidateNotNullOrEmpty()]
    [Parameter(
        ValueFromPipelineByPropertyName=$true)]
    $TemplateSource= $DefaultTemplateSources,

    [string]
    [ValidateScript({Test-Path $_ -PathType Container})]
    [Parameter(
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)]
    $ProjectRootDirPath = '.'

){

    <#
        .SYNOPSIS
        Adds a new task to a devop
        
        .PARAMETER TemplateVersion
        Description: 
        The version of the task template (identified by the TemplateId parameter) to use
               
        Default:                 
        the latest available version of the task template (identified by the TemplateId parameter)

        .PARAMETER Name
        Description: 
        The tasks name
               
        Default:                 
        the value of the TemplateId parameter

        .EXAMPLE
        Add-AppeaseTask -DevOpName DeployToAzure -TemplateId DeployNupkgToAzureWebsites -TemplateVersion '0.0.3'-Name LastTask 
        
        Description:

        Adds a task 'LastTask' after all existing tasks in devop 'DeployToAzure'. The task uses version '0.0.3' of
        the task template with id 'DeployNupkgToAzureWebsites'

        .EXAMPLE
        Add-AppeaseTask -DevOpName DeployToAzure -TemplateId DeployNupkgToAzureWebsites -First

        Description:

        Adds a task 'DeployNupkgToAzureWebsites' before all existing tasks in devop 'DeployToAzure'. The task 
        uses the latest version of the task template with id 'DeployNupkgToAzureWebsites'

        .EXAMPLE
        Add-AppeaseTask -DevOpName DeployToAzure -TemplateId DeployNupkgToAzureWebsites -After SecondTask

        Description:

        Adds a task 'DeployNupkgToAzureWebsites' after the existing task 'SecondTask' in devop 'DeployToAzure'.
        The task uses the latest version of the task template with id 'DeployNupkgToAzureWebsites'

        .EXAMPLE
        Add-AppeaseTask -DevOpName DeployToAzure -TemplateId DeployNupkgToAzureWebsites -Name BeforeSecondTask -Before SecondTask

        Description:

        Adds a task 'BeforeSecondTask" before the existing task 'SecondTask' in devop 'DeployToAzure'. The task 
        uses the latest version of the task template with id 'DeployNupkgToAzureWebsites'

    #>

        
        if([string]::IsNullOrWhiteSpace($TemplateVersion)){
            $TemplateVersion = TemplateManagement\Get-AppeaseTaskTemplateLatestVersion -Source $TemplateSource -Id $TemplateId
Write-Debug "using greatest available template version : $TemplateVersion"
        }
                
        if($First.IsPresent){
        
            $TaskIndex = 0
        
        }
        elseif('Add-AppeaseTaskAfter' -eq $PSCmdlet.ParameterSetName){
            
            $Tasks = DevOpStorage\Get-AppeaseDevOp -Name $DevOpName -ProjectRootDirPath $ProjectRootDirPath | Select -ExpandProperty Tasks
            $indexOfAfter = $Tasks.IndexOf(($Tasks|?{$_.Name -eq $After}))
            # ensure Task with key $After exists
            if($indexOfAfter -lt 0){
                throw "Task '$After' could not be found."
            }
            $TaskIndex = $indexOfAfter + 1
        
        }
        elseif('Add-AppeaseTaskBefore' -eq $PSCmdlet.ParameterSetName){        
        
            $Tasks = DevOpStorage\Get-AppeaseDevOp -Name $DevOpName -ProjectRootDirPath $ProjectRootDirPath | Select -ExpandProperty Tasks
            $indexOfBefore = $Tasks.IndexOf(($Tasks|?{$_.Name -eq $Before}))
            # ensure Task with key $Before exists
            if($indexOfBefore -lt 0){
                throw "Task '$Before' could not be found."
            }
            $TaskIndex = $indexOfBefore
        
        }
        else{
        
            $Tasks = DevOpStorage\Get-AppeaseDevOp -Name $DevOpName -ProjectRootDirPath $ProjectRootDirPath | Select -ExpandProperty Tasks
            $TaskIndex = $Tasks.Count
        }

        DevOpStorage\Add-AppeaseTask `
            -DevOpName $DevOpName `
            -Name $Name `
            -TemplateId $TemplateId `
            -TemplateVersion $TemplateVersion `
            -Index $TaskIndex `
            -Force:$Force `
            -ProjectRootDirPath $ProjectRootDirPath
}

function Update-AppeaseTaskTemplate(

    [CmdletBinding(
        DefaultParameterSetName="Update-All")]

    [string]
    [ValidateNotNullOrEmpty()]
    [Parameter(
        Mandatory=$true)]
    $DevOpName,

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
    $Source = $DefaultTemplateSources,

    [String]
    [ValidateScript({Test-Path $_ -PathType Container})]
    [Parameter(
        ValueFromPipelineByPropertyName=$true)]
    $ProjectRootDirPath='.'

){

    $DevOp = DevOpStorage\Get-AppeaseDevOp -Name $DevOpName -ProjectRootDirPath $ProjectRootDirPath

    # build up list of template updates
    $templateUpdates = @{}
    If('Update-Multiple' -eq $PSCmdlet.ParameterSetName){

        foreach($templateId in $Id){

            $templateUpdates.Add($templateId,(TemplateManagement\Get-AppeaseTaskTemplateLatestVersion -Source $Source -Id $templateId))

        }
    }
    ElseIf('Update-Single' -eq $PSCmdlet.ParameterSetName){
        
        if($Id.Length -ne 1){
            throw "Updating to an explicit template version is only allowed when updating a single template"
        }

        $templateUpdates.Add($Id,$Version)
    }
    Else{        
        
        foreach($Task in $DevOp.Tasks){

            $templateUpdates.Add($Task.TemplateId,(TemplateManagement\Get-AppeaseTaskTemplateLatestVersion -Source $Source -Id $Task.TemplateId))
        
        }
    }

    foreach($Task in $DevOp.Tasks){

        $updatedTemplateVersion = $templateUpdates.($Task.TemplateId)

        if($null -ne $updatedTemplateVersion){

            TemplateManagement\Uninstall-AppeaseTaskTemplate -Id $Task.TemplateId -Version $Task.TemplateVersion -ProjectRootDirPath $ProjectRootDirPath

Write-Debug `
@"
Updating task template '$($Task.TemplateId)'
from version '$($Task.TemplateVersion)'
to version '$($updatedTemplateVersion)'
for task '$($Task.Name)'
"@
            DevOpStorage\Set-AppeaseTaskTemplateVersion `
                -DevOpName $DevOpName `
                -TaskName $Task.Name `
                -TemplateVersion $updatedTemplateVersion `
                -ProjectRootDirPath $ProjectRootDirPath
        }
    }
}

Export-ModuleMember -Function @(
                                # DevOp API
                                'Invoke-AppeaseDevOp',
                                'New-AppeaseDevOp',
                                'Remove-AppeaseDevOp',
                                'Rename-AppeaseDevOp',
                                'Get-AppeaseDevOp',
                    
                                # Task API
                                'Add-AppeaseTask',
                                'Remove-AppeaseTask',
                                'Rename-AppeaseTask',
                                'Set-AppeaseTaskParameter',

                                # Configuration API
                                'Add-AppeaseConfiguration',
                                'Get-AppeaseConfiguration',
                                'Set-AppeaseConfigurationParentName',
                                'Set-AppeaseConfigurationVariable',
                                'Remove-AppeaseConfigurationVariable',
                                'Rename-AppeaseConfiguration',
                                'Remove-AppeaseConfiguration'

                                # Task Template API
                                'Update-AppeaseTaskTemplate',
                                'New-AppeaseTaskTemplatePackage',
                                'Publish-AppeaseTaskTemplateToNuGetFeed')
