###1 Custom Variables

###2 Automatic Variables
Posh-CI automatically makes certain variables available to ci-steps. The names of Posh-CI provided variables always start with the prefix `PoshCI`.
To use an automatic variable when creating a ci-step module, simply reference it in your Invoke-CIStep function.

Example:
```PowerShell
function Invoke-CIStep(
[string][Parameter(Mandatory=$true,ValueFromPipelineByPropertyName=$true)]$PoshCIProjectRootDirPath,
[string][Parameter(Mandatory=$true,ValueFromPipelineByPropertyName=$true)]$PoshCIStepName)
{
    # implementation snipped...
}

```

#####2.1 [string]$PoshCIProjectRootDirPath
Always available;equals the project root dir path of the currently executing ci-plan

#####2.2 [string]$StepName
Always available;equals the name of the currently executing ci-step
