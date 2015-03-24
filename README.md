###What problems does PoshDevOps attempt to solve?

Build/Deployment services today are extremely powerfull and easy to use. However, if you throw your DevOps together in most of these services you are left with: 
######-1 lack of versioning side by side source code 
######-2 coupling of implementation to a proprietary build/deployment service.
######-3 no capability to run outside of a proprietary build/deployment
######-4 expenses (subscriptions, licenses, hardware,  etc...)
######-5 one off scripts lacking any any sort of modularity
######-6 rampant copying/pasting, general lack of reuse

###How does PoshDevOps attempt to solve them?
######+1 versioning side by side source code
######+2 implemented as plain old PowerShell modules
######+3 ability to run anything capable of running PowerShell
######+4 no expenses (as long as you have something capable of running PowerShell ;))
######+5 all tasks are implemented as PowerShell modules
######+6 all tasks are package sourced and inherently reuseable

###How do I install it?
Make sure you have [Chocolatey](https://chocolatey.org) installed, then from PowerShell run
```POWERSHELL
choco install poshdevops -version 0.0.45; # 0.0.45 was latest at time of writing
Import-Module "C:\Program Files\PoshDevOps\Modules\PoshDevOps" -Force
```
###In a nutshell, hows it work?
***Conceptually:***
- `task groups` are an arbitrary set of tasks working towards a common goal   
  for example: "Build", "Unit Test", "Package", "Deploy", "Integration Test", .. etc
- `tasks` are arbitrary operations implemented as PowerShell modules and packaged as .nupkg's.    
  for example: a "Package" task group might have tasks: Copy Artifacts To Temp, Create NuGet Package

***Operationally:***
- everything takes place within PowerShell
- as you [CRUD](http://en.wikipedia.org/wiki/Create,_read,_update_and_delete) each `task group` a snapshot is maintained in a `TaskGroup.psd1` file.
- at any time you can invoke your `task group` and pass in any parameters your `tasks` rely on

###How do I get started?
navigate to the root directory of your project:
```POWERSHELL
Set-Location "PATH-TO-ROOT-DIR-OF-YOUR-PROJECT"
```
create a new task group:
```POWERSHELL
New-PoshDevOpsTaskGroup -Name Build
```
add a few tasks to your task group:
```POWERSHELL
Add-PoshDevOpsTask -Name "Restore NuGet Packages" -PackageId RestoreNuGetPackages
Add-PoshDevOpsTask -Name "Build Visual Studio Sln" -PackageId BuildVisualStudioSln
Add-PoshDevOpsTask -Name "Execute Unit Tests" -PackageId "InvokeVSTestConsole"
Add-PoshDevOpsTask -Name "Create NuGet Package" -PackageId "CreateNuGetPackage"
```
invoke your task group:
```POWERSHELL
@{"Create NuGet Package"=@{Version="0.0.1";OutputDirectoryPath=.}} | Invoke-PoshDevOpsTaskGroup -Name Build
```

###How do I distribute my task group?
When you run `New-PoshDevOpsTaskGroup` it creates a folder named `.PoshDevOps` at the root of your project. From then on all modifications to your task groups are maintained inside that folder so your .PoshDevOps folder is all you need!

(pro-tip: check your .PoshDevOps folder in to source control to version your task group along with your code.)

###Where's the documentation?
[Here](Docs)

###What's the build status
![](https://ci.appveyor.com/api/projects/status/jt0ppwagy4kmreap?svg=true)

###Interesting reading
[Distributed Continuous Integration - Keep the Mainline Clean](http://blog.assembla.com/AssemblaBlog/tabid/12618/bid/96937/Distributed-Continuous-Integration-Keep-the-Mainline-Clean.aspx)

