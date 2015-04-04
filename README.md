![](https://ci.appveyor.com/api/projects/status/i7bjw9a3u0g35spc?svg=true)

###How do I install it?
Make sure you have [Chocolatey](https://chocolatey.org) installed, then from PowerShell run
```POWERSHELL
choco install appease.client.powershell -y -version='0.0.77'
import-module 'C:\Program Files\Appease\PowerShell\Appease.Client' -Force
```
###In a nutshell, hows it work?
- A `devop` (development operation) is a set of related tasks  
  for example: "Build", "Unit Test", "Package", "Deploy", "Integration Test", .. etc
- `tasks` are arbitrary operations implemented as PowerShell modules and packaged as .nupkg's.    
  for example: a "Package Artifacts" devop might have tasks: CopyArtifactsToTemp, CreateNuGetPackage

###Whats the API look like?
```PowerShell
PS C:\> Get-Command -Module Appease.Client
 
CommandType     Name                                               Version    Source
-----------     ----                                               -------    ------
Function        Add-AppeaseTask                                    0.0.77     Appease.Client
Function        Get-AppeaseDevOp                                   0.0.77     Appease.Client
Function        Invoke-AppeaseDevOp                                0.0.77     Appease.Client
Function        New-AppeaseDevOp                                   0.0.77     Appease.Client
Function        Publish-AppeaseTaskTemplate                        0.0.77     Appease.Client
Function        Remove-AppeaseDevOp                                0.0.77     Appease.Client
Function        Remove-AppeaseTask                                 0.0.77     Appease.Client
Function        Rename-AppeaseDevOp                                0.0.77     Appease.Client
Function        Rename-AppeaseTask                                 0.0.77     Appease.Client
Function        Set-AppeaseTaskParameter                           0.0.77     Appease.Client
Function        Update-AppeaseTaskTemplate                         0.0.77     Appease.Client
```

###How do I get started?
navigate to the root directory of your project:
```PowerShell
Set-Location "PATH-TO-ROOT-DIR-OF-YOUR-PROJECT"
```
create a new devop:
```PowerShell
New-AppeaseDevOp Build
```
add a few tasks to your devop:
```PowerShell
Add-AppeaseTask -DevOpName Build -TemplateId RestoreNuGetPackages
Add-AppeaseTask -DevOpName Build -TemplateId BuildVisualStudioSln
Add-AppeaseTask -DevOpName Build -TemplateId InvokeVSTestConsole
Add-AppeaseTask -DevOpName Build -TemplateId CreateNuGetPackage
```
invoke your devop:
```PowerShell
@{CreateNuGetPackage=@{Version="0.0.1";OutputDirectoryPath=.}} | Invoke-AppeaseDevOp Build
```

###How do I distribute my devops?
Your devops are stored in json files following the format `YOUR-PROJECT-ROOT-DIR\.Appease\YOUR-DEVOP-NAME.json`. Make sure the `.Appease` directory is indexed by your version control and you're done.

pro-tip: exclude the `.Appease\Templates` folder from version control. Appease is smart enough to handle installing task templates when they're required and this way you don't unnecessarily bloat your version control. 

###Where's the documentation?
[Here](Docs)
