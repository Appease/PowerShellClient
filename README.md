###What is it?
Modular Continuous integration for any project à la PowerShell.

###How do I install it?
Make sure you have [Chocolatey](https://chocolatey.org) installed, then from PowerShell run
```POWERSHELL
cinst posh-ci
Import-Module "C:\Program Files\Posh-CI\Modules\Posh-CI"
```
###In a nutshell, hows it work?
- a `ci plan` consists of an arbitrary number of `ci steps`.
- each `ci step` achieves some task specific to your `ci plan`
- you can [CRUD](http://en.wikipedia.org/wiki/Create,_read,_update_and_delete) your `ci plan` directly from PowerShell [non] interactively and a snapshot is saved in a `CIPlanArchive.json` file.
- at any time you can invoke your `ci plan` and pass in any variables your tasks rely on from PowerShell either interactively or via script. 

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
Add-CIStep -Name "Compile" -ModulePath "PATH-TO-DIR-CONTAINING-MODULE"
```
invoke your ci plan:

(Note: we're piping it variables which will in turn be pipelined to each step of your ci plan)
```POWERSHELL
[PSCustomObject]@{Var1='Var1Value';Var2='Var2Value'} | Invoke-CIPlan
```

###Where's the documentation?
[Here](Documentation/Index.md)

###What's the build status
![](https://ci.appveyor.com/api/projects/status/ay2uucfxymlgk2ni?svg=true)

