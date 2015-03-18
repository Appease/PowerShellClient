###What problems does PoshDevOps attempt to solve?

Build/Deployment services today are extremely powerfull and easy to use. However, if you throw your ci-plan together in most of these services you are left with: 
######-1 lack of ci-plan versioning side by side with source code 
######-2 coupling of your ci-plan implementation to a proprietary build/deployment service.
######-3 no capability to run your ci-plan outside of a proprietary build/deployment service
######-4 expenses (subscriptions, licenses, hardware,  etc...)
######-5 one off scripts lacking any any sort of modularity
######-6 rampant copying/pasting, general lack of reuse amongst ci-plan components

###How does PoshDevOps attempt to solve them?
######+1 ci-plan versioning side by side with source code
######+2 ci-plan implemented as plain old PowerShell modules
######+3 ability to run your ci-plan on anything capable of running PowerShell
######+4 no expenses (as long as you have something capable of running PowerShell ;))
######+5 all ci-steps are implemented as PowerShell modules
######+6 all ci-steps are package based and inherently reuseable

###How do I install it?
Make sure you have [Chocolatey](https://chocolatey.org) installed, then from PowerShell run
```POWERSHELL
choco install poshdevops -version 0.0.9; # 0.0.9 was latest at time of writing
Import-Module "C:\Program Files\PoshDevOps\Modules\PoshDevOps" -Force
```
###In a nutshell, hows it work?
***Conceptually:***
- `ci plans` contain an ordered set of steps
- `ci steps` are arbitrary tasks which are implemented as PowerShell modules and packaged as .nupkg's.

***Operationally:***
- everything takes place within PowerShell
- as you [CRUD](http://en.wikipedia.org/wiki/Create,_read,_update_and_delete) your `ci plan` a snapshot is maintained in a `CIPlanArchive.psd1` file.
- at any time you can invoke your `ci plan` and pass in any variables your `ci steps` rely on

###How do I get started?
navigate to the root directory of your project:
```POWERSHELL
Set-Location "PATH-TO-ROOT-DIR-OF-YOUR-PROJECT"
```
create a new ci plan:
```POWERSHELL
New-CIPlan
```
add a step to your plan:
```POWERSHELL
Add-PoshDevOpsTask -Name "Compile" -ModulePath "PATH-TO-DIR-CONTAINING-MODULE"
```
invoke your ci plan:
```POWERSHELL
@{Compile=@{Var1='Value1';Var2='Value2'}} | Invoke-CIPlan
```

###How do I distribute my ci plan?
When you run `New-CIPlan` it creates a folder named `.PoshDevOps` at the root of your project. From then on all modifications to your ci plan are maintained inside that folder so your .PoshDevOps folder is all you need!

(pro-tip: check your .PoshDevOps folder in to source control to version your ci plan along with your code.)

###Where's the documentation?
[Here](Docs)

###What's the build status
![](https://ci.appveyor.com/api/projects/status/jt0ppwagy4kmreap?svg=true)

###Interesting reading
[Distributed Continuous Integration - Keep the Mainline Clean](http://blog.assembla.com/AssemblaBlog/tabid/12618/bid/96937/Distributed-Continuous-Integration-Keep-the-Mainline-Clean.aspx)

