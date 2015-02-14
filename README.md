###What is it?
Modular Continuous integration for any project à la PowerShell.

###How do I install it?
Make sure you have [Chocolatey](https://chocolatey.org) installed, then from PowerShell run
```POWERSHELL
cinst posh-ci;Import-Module "C:\Program Files\Posh-CI\Modules\Posh-CI" -Force
```
###In a nutshell, hows it work?
***Conceptually:***
- `ci plans` contain an ordered set of `ci steps`
- `ci steps` are arbitrary tasks which are implemented as PowerShell modules.

***Operationally:***
- everything takes place within PowerShell
- as you [CRUD](http://en.wikipedia.org/wiki/Create,_read,_update_and_delete) your `ci plan` a snapshot is maintained in a `CIPlanArchive.json` file.
- at any time you can invoke your `ci plan` and pass in any variables your `ci steps` rely on

###How do I get started?
navigate to the root directory of your project:
```POWERSHELL
Set-Location "PATH-TO-ROOT-DIR-OF-YOUR-PROJECT"
```
create a new ci plan:
```POWERSHELL
# note: this creates a folder named .posh-ci at the root of your project containing your ci-plan
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

###How do I distribute my ci plan?
When you run `New-CIPlan` it creates a folder named `.posh-ci` at the root of your project. From then on all modifications to your ci plan are maintained inside that folder so your .posh-ci folder is all you need!

(pro-tip: check your .posh-ci folder in to source control to version your ci plan along with your code.)

###Where's the documentation?
[Here](Docs)

###What's the build status
![](https://ci.appveyor.com/api/projects/status/ay2uucfxymlgk2ni?svg=true)

