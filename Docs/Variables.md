###1 Custom CI-Step Variables
When developing a ci-step that requires/allows configuration just add parameters to your Invoke-CIStep method signature and make sure to document this in your documentation.

Example:
```PowerShell
function Invoke-CIStep(
[string][Parameter(Mandatory=$true,ValueFromPipelineByPropertyName=$true)]$CustomParam1,
[string[]][Parameter(Mandatory=$true,ValueFromPipelineByPropertyName=$true)]$CustomParam2)
{
    # implementation snipped...
}

```

###2 Automatic CI-Step Variables
Posh-CI automatically makes certain variables available to ci-steps. The names of Posh-CI provided variables always start with the prefix `PoshCI`.
When developing a ci-steps that needs information about the executing ci-plan/ci-step just add the required parameters to your Invoke-CIStep method signature.

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
