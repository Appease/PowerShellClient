###1 Configurable Parameters
When developing a DevOps task that requires/allows configuration, add parameters to your Invoke-AppeaseTask method signature with type `string` and any desired name (excluding names beginning with Appease which is reserved for Automatic Parameters).

Example:
```PowerShell
function Invoke-AppeaseTask(
[string][Parameter(Mandatory=$true,ValueFromPipelineByPropertyName=$true)]$CustomParam1,
[string][Parameter(Mandatory=$true,ValueFromPipelineByPropertyName=$true)]$CustomParam2)
{
    # implementation snipped...
}

```

###2 Automatic Parameters
Appease will automatically populate certain DevOps task parameters, the names of which always start with the prefix `Appease`.
These parameters provide information about the executing task group/DevOps task. 

To use automatic parameters, add parameters matching the type and name of defined automatic parameters to your Invoke-AppeaseTask method signature and Appease will populate them at invocation time.

Example:
```PowerShell
function Invoke-AppeaseTask(
[string][Parameter(Mandatory=$true,ValueFromPipelineByPropertyName=$true)]$AppeaseProjectRootDirPath,
[string][Parameter(Mandatory=$true,ValueFromPipelineByPropertyName=$true)]$AppeaseTaskName)
{
    # implementation snipped...
}

```

#####2.1 [string]$AppeaseProjectRootDirPath
Always available;equals the project root dir path of the currently executing task group

#####2.2 [string]$TaskName
Always available;equals the name of the currently executing DevOps task
