Import-Module "$PSScriptRoot\Pson" -Force -Global

function Get-PoshDevOpsTaskGroup(
[string]
[ValidateScript({Test-Path $_ -PathType Container})]
[Parameter(
    ValueFromPipelineByPropertyName=$true)]
$ProjectRootDirPath = '.'){
    <#
        .SYNOPSIS
        parses a task group file
    #>

    $taskGroupFilePath = Resolve-Path "$ProjectRootDirPath\.PoshDevOps\TaskGroup.psd1"   
Write-Output (Get-Content $taskGroupFilePath | Out-String | ConvertFrom-Pson)

}

function Save-PoshDevOpsTaskGroup(
[PsCustomObject]
$TaskGroup,

[string]
[ValidateScript({Test-Path $_ -PathType Container})]
[Parameter(
    ValueFromPipelineByPropertyName=$true)]
$ProjectRootDirPath = '.'){
    <#
        .SYNOPSIS
        an internal utility function to snapshot and save a TaskGroup to disk
    #>
    
    $taskGroupFilePath = Resolve-Path "$ProjectRootDirPath\.PoshDevOps\TaskGroup.psd1"    
    Set-Content $taskGroupFilePath -Value (ConvertTo-Pson -InputObject $TaskGroup -Depth 12 -Layers 12 -Strict)
}

function Remove-PoshDevOpsTaskGroup(
[switch]
$Force,

[string]
[ValidateScript({Test-Path $_ -PathType Container})]
[Parameter(
    ValueFromPipelineByPropertyName=$true)]
$ProjectRootDirPath = '.'){
    
    $taskGroupDirPath = Resolve-Path "$ProjectRootDirPath\.PoshDevOps"

    $confirmationPromptQuery = "Are you sure you want to delete the task group located at $TaskGroupDirPath`?"
    $confirmationPromptCaption = 'Confirm task group removal'

    if($Force.IsPresent -or $PSCmdlet.ShouldContinue($confirmationPromptQuery,$confirmationPromptCaption)){
        Remove-Item -Path $taskGroupDirPath -Recurse -Force
    }
}

Export-ModuleMember -Function Get-PoshDevOpsTaskGroup
Export-ModuleMember -Function Save-PoshDevOpsTaskGroup
Export-ModuleMember -Function Remove-PoshDevOpsTaskGroup