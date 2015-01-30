**What is it?**
A PowerShell task runner inspired by the popular Javascript task runners [Gulp](http://gulpjs.com) and [Grunt](http://gruntjs.com).

**How do I install it?**
Make sure you have [Chocolatey](https://chocolatey.org) installed, then from PowerShell run
```
cinst posh-ci
Import-Module "C:\Program Files\Posh-CI\Modules\Posh-CI"
```

**How do I add it to my project?**
```
# navigate to the root directory of your project
Set-Location "THE-ROOT-DIR-OF-YOUR-PROJECT"

# create a new ci plan and initialize it with a 'Build' and a 'Unit-Test' stage
New-CIPlan Build,Unit-Test
```

**Where's the documentation?**
[Here](Documentation/Index.md)

**What's the build status**
![](https://ci.appveyor.com/api/projects/status/ay2uucfxymlgk2ni?svg=true)

