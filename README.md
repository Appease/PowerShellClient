![](https://ci.appveyor.com/api/projects/status/i7bjw9a3u0g35spc?svg=true)

###How do I install it?
Make sure you have [Chocolatey](https://chocolatey.org) installed, then from PowerShell run
```POWERSHELL
choco install appease.client.powershell -y -version='0.0.77'
import-module 'C:\Program Files\Appease\PowerShell\Appease.Client' -Force
```
###In a nutshell, hows it work?
***Conceptually:***
- A `devop` (development operation) is a set of related tasks  
  for example: "Build", "Unit Test", "Package", "Deploy", "Integration Test", .. etc
- `tasks` are arbitrary operations implemented as PowerShell modules and packaged as .nupkg's.    
  for example: a "Package Artifacts" devop might have tasks: CopyArtifactsToTemp, CreateNuGetPackage

***Operationally:***
- everything takes place within PowerShell
- as you create/edit your `devops` a snapshot of each is maintained in a `YOUR-DEVOP-NAME.json` file (under the .Appease directory).

###How do I get started?
navigate to the root directory of your project:
```POWERSHELL
Set-Location "PATH-TO-ROOT-DIR-OF-YOUR-PROJECT"
```
create a new devop:
```POWERSHELL
New-AppeaseDevOp Build
```
add a few tasks to your devop:
```POWERSHELL
Add-AppeaseTask -DevOpName Build -Name "Restore NuGet Packages" -TemplateId RestoreNuGetPackages
Add-AppeaseTask -DevOpName Build -Name "Build Visual Studio Sln" -TemplateId BuildVisualStudioSln
Add-AppeaseTask -DevOpName Build -Name "Execute Unit Tests" -TemplateId InvokeVSTestConsole
Add-AppeaseTask -DevOpName Build -Name "Create NuGet Package" -TemplateId CreateNuGetPackage
```
invoke your devop:
```POWERSHELL
@{CreateNuGetPackage=@{Version="0.0.1";OutputDirectoryPath=.}} | Invoke-AppeaseDevOp Build
```

###How do I distribute my devops?
When you invoke `New-AppeaseDevOp` for the first time it creates a folder named `.Appease` at the root of your project. Make sure you add this directory to version control and you're done. 

pro-tip: exclude the `.Appease\Templates` folder from version control. Appease is smart enough to handle installing task templates when they're required and this way you don't unnecessarily bloat your version control. 

###Where's the documentation?
[Here](Docs)
