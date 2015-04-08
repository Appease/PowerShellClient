![](https://ci.appveyor.com/api/projects/status/i7bjw9a3u0g35spc?svg=true)

###How do I install it?
Make sure you have >= v0.9.9 of [Chocolatey](https://chocolatey.org) installed, then from PowerShell run
```POWERSHELL
choco install appease.client.powershell -yxf -version='0.0.77'
import-module 'C:\Program Files\Appease\PowerShell\Appease.Client' -Force
```
###In a nutshell, hows it work?
- `devops` (development operations) are sets of related tasks  
  for example: a project might have 'Build', 'Unit Test', 'Package', 'Deploy', 'Integration Test' devops
- `tasks` are arbitrary operations implemented as PowerShell modules and packaged as .nupkg's.    
  for example: a 'Package' devop might have tasks: 'CopyArtifactsToTemp', 'CreateNuGetPackage'
- `configurations` define sets of parameters to pass to devop tasks.  
  for example: a "Deploy" devop might have configurations: 'Base','ChrisDev','Integration','QA','Demo','Prod'

###Whats the API look like?
```PowerShell
PS C:\> Get-Command -Module Appease.Client | Format-Table -AutoSize
 
CommandType Name                               ModuleName    
----------- ----                               ----------    
Function    Add-AppeaseConfiguration           Appease.Client
Function    Add-AppeaseTask                    Appease.Client
Function    Get-AppeaseConfiguration           Appease.Client
Function    Get-AppeaseDevOp                   Appease.Client
Function    Invoke-AppeaseDevOp                Appease.Client
Function    New-AppeaseDevOp                   Appease.Client
Function    Publish-AppeaseTaskTemplate        Appease.Client
Function    Remove-AppeaseConfiguration        Appease.Client
Function    Remove-AppeaseDevOp                Appease.Client
Function    Remove-AppeaseTask                 Appease.Client
Function    Rename-AppeaseConfiguration        Appease.Client
Function    Rename-AppeaseDevOp                Appease.Client
Function    Rename-AppeaseTask                 Appease.Client
Function    Set-AppeaseConfigurationParentName Appease.Client
Function    Set-AppeaseTaskParameter           Appease.Client
Function    Update-AppeaseTaskTemplate         Appease.Client
```

###How do I get started?
navigate to the root directory of your project:
```PowerShell
Set-Location "PATH-TO-ROOT-DIR-OF-YOUR-PROJECT"
```
create a 'Build' devop:
```PowerShell
New-AppeaseDevOp Build
```
add 'RestoreNuGetPackages','BuildVisualStudioSln','InvokeVSTestConsole', and 'CreateNuGetPackage' tasks to the 'Build' devop:
```PowerShell
Add-AppeaseTask -DevOpName Build -TemplateId RestoreNuGetPackages
Add-AppeaseTask -DevOpName Build -TemplateId BuildVisualStudioSln
Add-AppeaseTask -DevOpName Build -TemplateId InvokeVSTestConsole
Add-AppeaseTask -DevOpName Build -TemplateId CreateNuGetPackage
```
add a 'Base' configuration to the 'Build' devop
```PowerShell
Add-AppeaseConfiguration -Name Base -DevOpName Build
```

set the 'TestCaseFilter' parameter of the 'InvokeVSTestConsole' task in the 'Base' configuration of your 'Build' devop
```PowerShell
Set-AppeaseTaskParameter `
    -ConfigurationName Base `
    -DevOpName Build `
    -TaskName InvokeVSTestConsole `
    -TaskParameter @{TestCaseFilter='TestCategory=Unit'}
```

invoke the 'Build' devop with it's 'base' configuration:
```PowerShell
Invoke-AppeaseDevOp -Name Build -ConfigurationName Base
```

###How do I distribute my devops?
Your devops are stored in json files in devop specific directories following the format `YOUR-PROJECT-ROOT-DIR\.Appease\DevOps\YOUR-DEVOP-NAME`. Make sure the `.Appease\DevOps` directory is indexed by your version control and you're set.

pro-tip: make sure the `.Appease\Templates` folder is excluded from your version control. Appease is smart enough to handle installing task templates when they're required and this way you don't unnecessarily bloat your version control. 

###Where's the documentation?
[Here](Docs)
