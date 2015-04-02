Import-Module "$PSScriptRoot\TemplateManagement"
Import-Module "$PSScriptRoot\DevOpStorage"
Import-Module "$PSScriptRoot\HashtableExtensions"

function Invoke-AppeaseDevOp(

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
    $TemplateSource = $DefaultTemplateSources,

    [String]
    [ValidateScript({Test-Path $_ -PathType Container})]
    [Parameter(
        ValueFromPipelineByPropertyName=$true)]
    $ProjectRootDirPath='.'){        

    $DevOp = DevOpStorage\Get-AppeaseDevOp -Name $Name -ProjectRootDirPath $ProjectRootDirPath

    foreach($Task in $DevOp.Tasks){
                    
        if($Parameters.($Task.Name)){

            if($Task.Parameters){

Write-Debug "Adding union of passed parameters and archived parameters to pipeline. Passed parameters will override archived parameters"
                
                $TaskParameters = HashtableExtensions\Get-UnionOfHashtables -Source1 $Parameters.($Task.Name) -Source2 $Task.Parameters

            }
            else{

Write-Debug "Adding passed parameters to pipeline"

                $TaskParameters = $Parameters.($Task.Name)
            
            }

        }
        elseif($Task.Parameters){

Write-Debug "Adding archived parameters to pipeline"    
            $TaskParameters = $Task.Parameters

        }
        else{
                
            $TaskParameters = @{}
            
        }

Write-Debug "Adding automatic parameters to pipeline"
            
        $TaskParameters.AppeaseProjectRootDirPath = (Resolve-Path $ProjectRootDirPath)
        $TaskParameters.AppeaseTaskName = $Task.Name

Write-Debug "Ensuring task template installed"
        TemplateManagement\Install-AppeaseTaskTemplate -Id $Task.TemplateId -Version $Task.TemplateVersion -Source $TemplateSource
        $TaskTemplateInstallDirPath = TemplateManagement\Get-AppeaseTaskTemplateInstallDirPath -Id $Task.TemplateId -Version $Task.TemplateVersion -ProjectRootDirPath $ProjectRootDirPath
        $ModuleDirPath = "$TaskTemplateInstallDirPath\bin\$($Task.TemplateId)"
Write-Debug "Importing module located at: $ModuleDirPath"
        Import-Module $ModuleDirPath -Force

Write-Debug `
@"
Invoking Task $($Task.Name) with parameters: 
$($TaskParameters|Out-String)
"@
        
        # Parameters must be PSCustomObject so [Parameter(ValueFromPipelineByPropertyName = $true)] works
        [PSCustomObject]$TaskParameters.Clone() | & "$($Task.TemplateId)\Invoke"

        Remove-Module $Task.TemplateId

    }
}

function New-AppeaseDevOp(

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
    
    $DevOp = @{Name=$Name;Tasks={@()}.Invoke()}

    DevOpStorage\Add-AppeaseDevOp `
        -Value $DevOp `
        -Force:$Force `
        -ProjectRootDirPath $ProjectRootDirPath
}

function Remove-AppeaseDevOp(

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

    $ConfirmationPromptQuery = "Are you sure you want to delete the DevOp `"$Name`"`?"
    $ConfirmationPromptCaption = 'Confirm Task removal'

    if($Force.IsPresent -or $PSCmdlet.ShouldContinue($ConfirmationPromptQuery,$ConfirmationPromptCaption)){

        DevOpStorage\Remove-AppeaseDevOp `
            -Name $Name `
            -ProjectRootDirPath $ProjectRootDirPath

    }

}

function Rename-AppeaseDevOp(

[string]
[ValidateNotNullOrEmpty()]
[Parameter(
    Mandatory=$true)]
$OldName,

[string]
[ValidateNotNullOrEmpty()]
[Parameter(
    Mandatory=$true)]
$NewName,

[switch]
$Force,

[string]
[ValidateScript({Test-Path $_ -PathType Container})]
[Parameter(
    ValueFromPipeline=$true,
    ValueFromPipelineByPropertyName=$true)]
$ProjectRootDirPath = '.'){

    DevOpStorage\Rename-AppeaseDevOp `
        -OldName $OldName `
        -NewName $NewName `
        -Force:$Force `
        -ProjectRootDirPath $ProjectRootDirPath    

}

function Get-AppeaseDevOp(

[string]
[ValidateNotNullOrEmpty()]
[Parameter(
    Mandatory=$true)]
$Name,

[string]
[ValidateScript({Test-Path $_ -PathType Container})]
[Parameter(
    ValueFromPipelineByPropertyName=$true)]
$ProjectRootDirPath = '.'){

    DevOpStorage\Get-AppeaseDevOp -Name $Name -ProjectRootDirPath $ProjectRootDirPath | Write-Output

}

function Add-AppeaseTask(
[CmdletBinding(
    DefaultParameterSetName="Add-AppeaseTaskLast")]

[string]
[ValidateNotNullOrEmpty()]
[Parameter(
    Mandatory=$true)]
$DevOpName,

[string]
[ValidateNotNullOrEmpty()]
[Parameter(
    Mandatory=$true)]
$Name,

[string]
[Parameter(
    Mandatory=$true)]
$TemplateId,

[string]
$TemplateVersion,

[switch]
[Parameter(
    Mandatory=$true,
    ParameterSetName='Add-AppeaseTaskFirst')]
$First,

[switch]
[Parameter(
    ParameterSetName='Add-AppeaseTaskLast')]
$Last,

[string]
[Parameter(
    Mandatory=$true,
    ParameterSetName='Add-AppeaseTaskAfter')]
$After,

[string]
[Parameter(
    Mandatory=$true,
    ParameterSetName='Add-AppeaseTaskBefore')]
$Before,

[switch]
$Force,

[string[]]
[ValidateNotNullOrEmpty()]
$TemplateSource= $DefaultTemplateSources,

[string]
[ValidateScript({Test-Path $_ -PathType Container})]
[Parameter(
    ValueFromPipeline=$true,
    ValueFromPipelineByPropertyName=$true)]
$ProjectRootDirPath = '.'){

    <#
        .SYNOPSIS
        Adds a new Task to a DevOp
        
        .EXAMPLE
        Add-AppeaseTask -DevOpName "Deploy To Azure" -Name "LastTask" -TemplateId "DeployNupkgToAzureWebsites" -TemplateVersion "0.0.3"
        
        Description:

        This command adds Task "LastTask" after all existing Tasks in DevOp "Deploy To Azure"

        .EXAMPLE
        Add-AppeaseTask -DevOpName "Deploy To Azure" -Name "FirstTask" -TemplateId "DeployNupkgToAzureWebsites" -First

        Description:

        This command adds Task "FirstTask" before all existing Tasks in DevOp "Deploy To Azure"

        .EXAMPLE
        Add-AppeaseTask -DevOpName "Deploy To Azure" -Name "AfterSecondTask" -TemplateId "DeployNupkgToAzureWebsites" -After "SecondTask"

        Description:

        This command adds Task "AfterSecondTask" after the existing Task "SecondTask" in DevOp "Deploy To Azure"

        .EXAMPLE
        Add-AppeaseTask -DevOpName "Deploy To Azure" -Name "BeforeSecondTask" -TemplateId "DeployNupkgToAzureWebsites" -Before "SecondTask"

        Description:

        This command adds Task "BeforeSecondTask" before the existing Task "SecondTask" in DevOp "Deploy To Azure"

    #>

        
        if([string]::IsNullOrWhiteSpace($TemplateVersion)){
            $TemplateVersion = TemplateManagement\Get-AppeaseTaskTemplateLatestVersion -Source $TemplateSource -Id $TemplateId
Write-Debug "using greatest available template version : $TemplateVersion"
        }
                
        if($First.IsPresent){
        
            $TaskIndex = 0
        
        }
        elseif('Add-AppeaseTaskAfter' -eq $PSCmdlet.ParameterSetName){
            
            $DevOp = DevOpStorage\Get-AppeaseDevOp -Name $DevOpName -ProjectRootDirPath $ProjectRootDirPath
            $indexOfAfter = $DevOp.Tasks.IndexOf(($DevOp.Tasks|?{$_.Name -eq $After}|Select -First 1))
            # ensure Task with key $After exists
            if($indexOfAfter -lt 0){
                throw "A task with name $After could not be found."
            }
            $TaskIndex = $indexOfAfter + 1
        
        }
        elseif('Add-AppeaseTaskBefore' -eq $PSCmdlet.ParameterSetName){        
        
            $DevOp = DevOpStorage\Get-AppeaseDevOp -Name $DevOpName -ProjectRootDirPath $ProjectRootDirPath
            $indexOfBefore = $DevOp.Tasks.IndexOf(($DevOp.Tasks|?{$_.Name -eq $Before}|Select -First 1))
            # ensure Task with key $Before exists
            if($indexOfBefore -lt 0){
                throw "A Task with name $Before could not be found."
            }
            $TaskIndex = $indexOfBefore
        
        }
        else{
        
            $DevOp = DevOpStorage\Get-AppeaseDevOp -Name $DevOpName -ProjectRootDirPath $ProjectRootDirPath
            $TaskIndex = $DevOp.Tasks.Count  
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

function Remove-AppeaseTask(

[string]
[ValidateNotNullOrEmpty()]
[Parameter(
    Mandatory=$true)]
$DevOpName,

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

    $ConfirmationPromptQuery = "Are you sure you want to remove the Task with name $Name`?"
    $ConfirmationPromptCaption = 'Confirm Task removal'

    if($Force.IsPresent -or $PSCmdlet.ShouldContinue($ConfirmationPromptQuery,$ConfirmationPromptCaption)){

        DevOpStorage\Remove-AppeaseTask `
            -DevOpName $DevOpName `
            -Name $Name `
            -ProjectRootDirPath $ProjectRootDirPath

    }

}

function Rename-AppeaseTask(

[string]
[ValidateNotNullOrEmpty()]
[Parameter(
    Mandatory=$true)]
$DevOpName,

[string]
[ValidateNotNullOrEmpty()]
[Parameter(
    Mandatory=$true)]
$OldName,

[string]
[ValidateNotNullOrEmpty()]
[Parameter(
    Mandatory=$true)]
$NewName,

[switch]$Force,

[string]
[ValidateScript({Test-Path $_ -PathType Container})]
[Parameter(
    ValueFromPipelineByPropertyName=$true)]
$ProjectRootDirPath = '.'){

    DevOpStorage\Rename-AppeaseTask `
        -DevOpName $DevOpName `
        -OldName $OldName `
        -NewName $NewName `
        -Force:$Force `
        -ProjectRootDirPath $ProjectRootDirPath

}

function Set-AppeaseTaskParameter(

[string]
[ValidateNotNullOrEmpty()]
[Parameter(
    Mandatory=$true)]
$DevOpName,

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
        Sets configurable parameters of a Task
        
        .EXAMPLE
        Set-AppeaseTaskParameter -DevOpName Build -TaskName GitClone -Name GitParameters -Value Status -Force
        
        Description:

        This command sets the parameter "GitParameters" to "Status" for a Task "GitClone" in DevOp "Build"
    #>

    DevOpStorage\Set-AppeaseTaskParameter `
        -DevOpName $DevOpName `
        -TaskName $TaskName `
        -Name $Name `
        -Value $Value `
        -Force:$Force
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
$ProjectRootDirPath='.'){

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

                                # Task Template API
                                'Update-AppeaseTaskTemplate',
                                'Publish-AppeaseTaskTemplate')
