###1 Custom Parameters
When developing a ci-step that requires/allows configuration, add custom parameters to your Invoke-CIStep method signature and make sure to provide documentation.

Example:
```PowerShell
function Invoke-CIStep(
[string][Parameter(Mandatory=$true,ValueFromPipelineByPropertyName=$true)]$CustomParam1,
[string[]][Parameter(Mandatory=$true,ValueFromPipelineByPropertyName=$true)]$CustomParam2)
{
    # implementation snipped...
}

```

###2 Automatic Parameters
Posh-CI will automatically populate certain ci-step parameters, the names of which always start with the prefix `PoshCI`.
These parameters provide information about the executing ci-plan/ci-step. 

To use automatic parameters, add parameters matching the type and name of defined automatic parameters to your Invoke-CIStep method signature and Posh-CI will populate them at invocation time.

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
