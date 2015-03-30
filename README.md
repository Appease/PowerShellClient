###How do I install it?
Make sure you have [Chocolatey](https://chocolatey.org) installed, then from PowerShell run
```POWERSHELL
choco install appease -version 0.0.69; # 0.0.69 was latest at time of writing
Import-Module "C:\Program Files\Appease\Modules\Appease" -Force
```
###In a nutshell, hows it work?
***Conceptually:***
- A `DevOp` (development operation) is a set of related tasks  
  for example: "Build", "Unit Test", "Package", "Deploy", "Integration Test", .. etc
- `tasks` are arbitrary operations implemented as PowerShell modules and packaged as .nupkg's.    
  for example: a "Package Artifacts" DevOp might have tasks: Copy Artifacts To Temp, Create NuGet Package

***Operationally:***
- everything takes place within PowerShell
- as you create/edit your `DevOps` a snapshot of each is maintained in a `YOUR-DEVOP-NAME.psd1` file (under the .Appease directory).

###How do I get started?
navigate to the root directory of your project:
```POWERSHELL
Set-Location "PATH-TO-ROOT-DIR-OF-YOUR-PROJECT"
```
create a new DevOp:
```POWERSHELL
New-DevOp -Name Build
```
add a few tasks to your DevOp:
```POWERSHELL
Add-DevOpTask -DevOpName Build -Name "Restore NuGet Packages" -PackageId RestoreNuGetPackages
Add-DevOpTask -DevOpName Build -Name "Build Visual Studio Sln" -PackageId BuildVisualStudioSln
Add-DevOpTask -DevOpName Build -Name "Execute Unit Tests" -PackageId InvokeVSTestConsole
Add-DevOpTask -DevOpName Build -Name "Create NuGet Package" -PackageId CreateNuGetPackage
```
invoke your DevOp:
```POWERSHELL
@{"Create NuGet Package"=@{Version="0.0.1";OutputDirectoryPath=.}} | Invoke-DevOp -Name Build
```

###How do I distribute my DevOps?
When you invoke `New-DevOp` for the first time it creates a folder named `.Appease` at the root of your project. Make sure you add this directory to version control and you're done. 

pro-tip: exclude the `.PoshDevops\packages` folder from version control. Appease is smart enough to handle re-downloading any DevOp packages when it needs them and this way you don't bloat your version control. 

###Where's the documentation?
[Here](Docs)

###What's the build status
![](https://ci.appveyor.com/api/projects/status/t95vdsnjbmg9hnli?svg=true)
