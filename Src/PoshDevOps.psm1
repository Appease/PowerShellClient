Import-Module "$PSScriptRoot\PackageManagement"
Import-Module "$PSScriptRoot\DevOpStorage"
Import-Module "$PSScriptRoot\HashtableExtensions"
Import-Module "$PSScriptRoot\OrderedDictionaryExtensions"

function Invoke-DevOp(

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
    
    $DevOp = DevOpStorage\Get-DevOp -Name $Name -ProjectRootDirPath $ProjectRootDirPath

    if($DevOp){        

        foreach($task in $DevOp.Tasks.Values){
                    
            if($Parameters.($task.Name)){

                if($task.Parameters){

Write-Debug "Adding union of passed parameters and archived parameters to pipeline. Passed parameters will override archived parameters"
                
                    $taskParameters = HashtableExtensions\Get-UnionOfHashtables -Source1 $Parameters.($task.Name) -Source2 $task.Parameters

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
            PackageManagement\Install-DevOpTaskPackage -Id $task.PackageId -Version $task.PackageVersion -Source $PackageSource

            $moduleDirPath = "$ProjectRootDirPath\.PoshDevOps\packages\$($task.PackageId).$($task.PackageVersion)\$($task.PackageId)"
Write-Debug "Importing module located at: $moduleDirPath"
            Import-Module $moduleDirPath -Force

Write-Debug `
@"
Invoking task $($task.Name) with parameters: 
$($taskParameters|Out-String)
"@
            # Parameters must be PSCustomObject so [Parameter(ValueFromPipelineByPropertyName = $true)] works
            [PSCustomObject]$taskParameters.Clone() | & "$($task.PackageId)\Invoke"

            Remove-Module $task.PackageId

        }
    }
    else{

throw "DevOp.psd1 not found at: $taskGroupFilePath"

    }
}

function New-DevOp(

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
    
    $DevOp = @{Name=$Name;Tasks=[ordered]@{}}

    DevOpStorage\Add-DevOp `
        -Value $DevOp `
        -Force:$Force `
        -ProjectRootDirPath $ProjectRootDirPath
}

function Remove-DevOp(

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

    $confirmationPromptQuery = "Are you sure you want to delete the DevOp `"$Name`"`?"
    $confirmationPromptCaption = 'Confirm task removal'

    if($Force.IsPresent -or $PSCmdlet.ShouldContinue($confirmationPromptQuery,$confirmationPromptCaption)){

        DevOpStorage\Remove-DevOp `
            -Name $Name `
            -ProjectRootDirPath $ProjectRootDirPath

    }

}

function Rename-DevOp(
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

    DevOpStorage\Rename-DevOp `
        -OldName $OldName `
        -NewName $NewName `
        -Force:$Force `
        -ProjectRootDirPath $ProjectRootDirPath    

}

function Get-DevOp(

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

    DevOpStorage\Get-DevOp -Name $Name -ProjectRootDirPath $ProjectRootDirPath | Write-Output

}

function Add-DevOpTask(
[CmdletBinding(
    DefaultParameterSetName="Add-DevOpTaskLast")]

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
$PackageId,

[string]
$PackageVersion,

[switch]
[Parameter(
    Mandatory=$true,
    ParameterSetName='Add-DevOpTaskFirst')]
$First,

[switch]
[Parameter(
    ParameterSetName='Add-DevOpTaskLast')]
$Last,

[string]
[Parameter(
    Mandatory=$true,
    ParameterSetName='Add-DevOpTaskAfter')]
$After,

[string]
[Parameter(
    Mandatory=$true,
    ParameterSetName='Add-DevOpTaskBefore')]
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
        Adds a new task to a DevOp
        
        .EXAMPLE
        Add-DevOpTask -DevOp "Deploy To Azure" -Name "LastTask" -PackageId "DeployNupkgToAzureWebsites" -PackageVersion "0.0.3"
        
        Description:

        This command adds task "LastTask" after all existing tasks in DevOp "Deploy To Azure"

        .EXAMPLE
        Add-DevOpTask -DevOp "Deploy To Azure" -Name "FirstTask" -PackageId "DeployNupkgToAzureWebsites" -First

        Description:

        This command adds task "FirstTask" before all existing tasks in DevOp "Deploy To Azure"

        .EXAMPLE
        Add-DevOpTask -DevOp "Deploy To Azure" -Name "AfterSecondTask" -PackageId "DeployNupkgToAzureWebsites" -After "SecondTask"

        Description:

        This command adds task "AfterSecondTask" after the existing task "SecondTask" in DevOp "Deploy To Azure"

        .EXAMPLE
        Add-DevOpTask -DevOp "Deploy To Azure" -Name "BeforeSecondTask" -PackageId "DeployNupkgToAzureWebsites" -Before "SecondTask"

        Description:

        This command adds task "BeforeSecondTask" before the existing task "SecondTask" in DevOp "Deploy To Azure"

    #>

        
        if([string]::IsNullOrWhiteSpace($PackageVersion)){
            $PackageVersion = PackageManagement\Get-LatestDevOpTaskPackageVersion -Source $PackageSource -Id $PackageId
Write-Debug "using greatest available package version : $PackageVersion"
        }
                
        if($First.IsPresent){
        
            $TaskIndex = 0
        
        }
        elseif('Add-DevOpTaskAfter' -eq $PSCmdlet.ParameterSetName){
            
            $DevOp = DevOpStorage\Get-DevOp -Name $DevOpName -ProjectRootDirPath $ProjectRootDirPath
            $indexOfAfter = OrderedDictionaryExtensions\Get-IndexOfKeyInOrderedDictionary -Key $After -OrderedDictionary $DevOp.Tasks
            # ensure task with key $After exists
            if($indexOfAfter -lt 0){
                throw "A task with name $After could not be found."
            }
            $TaskIndex = $indexOfAfter + 1
        
        }
        elseif('Add-DevOpTaskBefore' -eq $PSCmdlet.ParameterSetName){        
        
            $DevOp = DevOpStorage\Get-DevOp -Name $DevOpName -ProjectRootDirPath $ProjectRootDirPath
            $indexOfBefore = OrderedDictionaryExtensions\Get-IndexOfKeyInOrderedDictionary -Key $Before -OrderedDictionary $DevOp.Tasks
            # ensure task with key $Before exists
            if($indexOfBefore -lt 0){
                throw "A task with name $Before could not be found."
            }
            $TaskIndex = $indexOfBefore
        
        }
        else{
        
            $DevOp = DevOpStorage\Get-DevOp -Name $DevOpName -ProjectRootDirPath $ProjectRootDirPath
            $TaskIndex = $DevOp.Tasks.Count  
        }

        DevOpStorage\Add-DevOpTask `
            -DevOpName $DevOpName `
            -Name $Name `
            -PackageId $PackageId `
            -PackageVersion $PackageVersion `
            -Index $TaskIndex `
            -Force:$Force `
            -ProjectRootDirPath $ProjectRootDirPath
}

function Remove-DevOpTask(

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

    $confirmationPromptQuery = "Are you sure you want to remove the task with name $Name`?"
    $confirmationPromptCaption = 'Confirm task removal'

    if($Force.IsPresent -or $PSCmdlet.ShouldContinue($confirmationPromptQuery,$confirmationPromptCaption)){

        DevOpStorage\Remove-DevOpTask `
            -DevOpName $DevOpName `
            -Name $Name `
            -ProjectRootDirPath $ProjectRootDirPath

    }

}

function Rename-DevOpTask(

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

    DevOpStorage\Rename-DevOpTask `
        -DevOpName $DevOpName `
        -OldName $OldName `
        -NewName $NewName `
        -Force:$Force `
        -ProjectRootDirPath $ProjectRootDirPath

}

function Set-DevOpTaskParameter(

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
        Sets configurable parameters of a task
        
        .EXAMPLE
        Set-DevOpTaskParameter -DevOpName Build -TaskName GitClone -Name GitParameters -Value Status -Force
        
        Description:

        This command sets the parameter "GitParameters" to "Status" for a task "GitClone" in DevOp "Build"
    #>

    DevOpStorage\Set-DevOpTaskParameter `
        -DevOpName $DevOpName `
        -TaskName $TaskName `
        -Name $Name `
        -Value $Value `
        -Force:$Force
}

function Update-DevOpTaskPackage(

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
$Source = $DefaultPackageSources,

[String]
[ValidateScript({Test-Path $_ -PathType Container})]
[Parameter(
    ValueFromPipelineByPropertyName=$true)]
$ProjectRootDirPath='.'){

    $DevOp = DevOpStorage\Get-DevOp -Name $DevOpName -ProjectRootDirPath $ProjectRootDirPath

    # build up list of package updates
    $packageUpdates = @{}
    If('Update-Multiple' -eq $PSCmdlet.ParameterSetName){

        foreach($packageId in $Id){

            $packageUpdates.Add($packageId,(PackageManagement\Get-LatestDevOpTaskPackageVersion -Source $Source -Id $packageId))

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

            $packageUpdates.Add($task.PackageId,(PackageManagement\Get-LatestDevOpTaskPackageVersion -Source $Source -Id $task.PackageId))
        
        }
    }

    foreach($task in $taskGroup.Tasks.Values){

        $updatedPackageVersion = $packageUpdates.($task.PackageId)

        if($null -ne $updatedPackageVersion){

            PackageManagement\Uninstall-DevOpTaskPackage -Id $task.PackageId -Version $task.PackageVersion -ProjectRootDirPath $ProjectRootDirPath

Write-Debug `
@"
Updating task "$($task.Name)" package "$($task.PackageId)"
from version "$($task.PackageVersion)"
to version "$($updatedPackageVersion)"
"@
            DevOpStorage\Update-DevOpTaskPackageVersion `
                -DevOpName $DevOpName `
                -TaskName $task.Name `
                -PackageVersion $updatedPackageVersion `
                -ProjectRootDirPath $ProjectRootDirPath
        }
    }
}

Export-ModuleMember -Function @(
                                # DevOp API
                                'Invoke-DevOp',
                                'New-DevOp',
                                'Remove-DevOp',
                                'Rename-DevOp',
                                'Get-DevOp',
                    
                                # DevOp Task API
                                'Add-DevOpTask',
                                'Remove-DevOpTask',
                                'Rename-DevOpTask',
                                'Set-DevOpTaskParameter',

                                # DevOp Task Package API
                                'Update-DevOpTaskPackage',
                                'New-DevOpTaskPackageSpec')