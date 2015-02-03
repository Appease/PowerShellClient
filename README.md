**What is it?**
A PowerShell task runner inspired by the popular Javascript task runners [Gulp](http://gulpjs.com) and [Grunt](http://gruntjs.com).

**How do I install it?**
Make sure you have [Chocolatey](https://chocolatey.org) installed, then from PowerShell run
```
cinst posh-ci
Import-Module "C:\Program Files\Posh-CI\Modules\Posh-CI"
```

**How do I use it?**
```
# navigate to the root directory of your project
Set-Location "THE-ROOT-DIR-OF-YOUR-PROJECT"

# create a new ci plan
New-CIPlan

# add a ci stage
Add-CIStep -Name "Dev"

# invoke your ci plan
Invoke-CIPlan
```

**Where's the documentation?**
[Here](Documentation/Index.md)

**What's the build status**
![](https://ci.appveyor.com/api/projects/status/ay2uucfxymlgk2ni?svg=true)

