###1 Configurable Parameters
When developing a DevOps step that requires/allows configuration, add parameters to your Invoke-PoshDevOpsTask method signature with type `string` and any desired name (excluding names beginning with PoshDevOps which is reserved for Automatic Parameters).

Example:
```PowerShell
function Invoke-PoshDevOpsTask(
[string][Parameter(Mandatory=$true,ValueFromPipelineByPropertyName=$true)]$CustomParam1,
[string][Parameter(Mandatory=$true,ValueFromPipelineByPropertyName=$true)]$CustomParam2)
{
    # implementation snipped...
}

```

###2 Automatic Parameters
Posh-CI will automatically populate certain DevOps step parameters, the names of which always start with the prefix `PoshDevOps`.
These parameters provide information about the executing ci-plan/DevOps step. 

To use automatic parameters, add parameters matching the type and name of defined automatic parameters to your Invoke-PoshDevOpsTask method signature and Posh-CI will populate them at invocation time.

Example:
```PowerShell
function Invoke-PoshDevOpsTask(
[string][Parameter(Mandatory=$true,ValueFromPipelineByPropertyName=$true)]$PoshDevOpsProjectRootDirPath,
[string][Parameter(Mandatory=$true,ValueFromPipelineByPropertyName=$true)]$PoshDevOpsStepName)
{
    # implementation snipped...
}

```

#####2.1 [string]$PoshDevOpsProjectRootDirPath
Always available;equals the project root dir path of the currently executing ci-plan

#####2.2 [string]$StepName
Always available;equals the name of the currently executing DevOps step
