###What is it?
Modular Continuous integration for any project à la PowerShell.

###How do I install it?
Make sure you have [Chocolatey](https://chocolatey.org) installed, then from PowerShell run
```POWERSHELL
cinst posh-ci
Import-Module "C:\Program Files\Posh-CI\Modules\Posh-CI"
```

###How do I use it?

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

(Note: we're piping it a PSCustomObject containing variables which will in turn be pipelined to each step of your ci plan)
```POWERSHELL
[PSCustomObject]@{Var1='Var1Value';Var2='Var2Value'} | Invoke-CIPlan
```

###Where's the documentation?
[Here](Documentation/Index.md)

###What's the build status
![](https://ci.appveyor.com/api/projects/status/ay2uucfxymlgk2ni?svg=true)

