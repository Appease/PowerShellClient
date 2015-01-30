**What is it?**
A PowerShell task runner inspired by the popular Javascript task runners [Gulp](http://gulpjs.com) and [Grunt](http://gruntjs.com).

**How do I install it?**
Make sure you have [Chocolatey](https://chocolatey.org) installed, then from PowerShell run
```
cinst posh-ci
Import-Module "$env:ChocolateyInstall\chocolateyinstall\helpers\chocolateyInstaller"
Update-SessionEnvironment
```

**How do I use it?**
  1. Navigate to the root directory of your project
  2. Create a `Posh-CI-File.ps1` containing your tasks
  3. Create a [Packages.config](https://github.com/chocolatey/chocolatey/wiki/CommandsInstall#packagesconfig---v09813) identifying any dependencies of the tasks in your `Posh-CI-File.ps1`

**Where's the documentation?**
[Here](Documentation/Index.md)

**What's the build status**
![](https://ci.appveyor.com/api/projects/status/ay2uucfxymlgk2ni?svg=true)

