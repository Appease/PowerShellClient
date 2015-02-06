function EnsureChocolateyInstalled(){

    # install chocolatey
    try{
        Get-Command choco -ErrorAction 'Stop' | Out-Null
    }
    catch{             
        iex ((new-object net.webclient).DownloadString('https://chocolatey.org/install.ps1'))
    }

}

function ConvertTo-CIPlanArchiveJson(
[PSCustomObject][Parameter(Mandatory=$true)]$CIPlan){
    <#
        .SUMMARY
        an internal utility function to convert a runtime CIPlan object to a 
        ci plan archive formatted as a json string
    #>

    # construct ci plan archive from ci plan
    $ciPlanArchiveSteps = @()
    $CIPlan.Steps.Values | %{$ciPlanArchiveSteps += $_}
    $ciPlanArchive = [PSCustomObject]@{'Steps'=$ciPlanArchiveSteps}

    Write-Output (ConvertTo-Json -InputObject $ciPlanArchive -Depth 4)

}

function ConvertFrom-CIPlanArchiveJson(
[string]$CIPlanFileContent){
    <#
        .SUMMARY
        an internal utility function to convert a ci plan archive formatted as a json string
        into a runtime CIPlan object.
    #>

    $ciPlanArchive = $CIPlanFileContent -join "`n" | ConvertFrom-Json

    # construct a ci plan from a ci plan archive
    $ciPlanSteps = [ordered]@{}
    $ciPlanArchive.Steps | %{$ciPlanSteps.Add($_.Name,$_)}
    
    Write-Output ([pscustomobject]@{'Steps'=$ciPlanSteps})

}

function Get-CIPlan(
[string]
[Parameter(
    ValueFromPipeline=$true,
    ValueFromPipelineByPropertyName=$true)]
$ProjectRootDirPath = '.'){
    <#
        .SUMMARY
        a utility function to parse a ci plan archive and 
        instantiate a runtime CIPlan object.
    #>

    $ciPlanFilePath = Resolve-Path "$ProjectRootDirPath\CIPlan\CIPlanArchive.json"   
    Write-Output (ConvertFrom-CIPlanArchiveJson -CIPlanFileContent (Get-Content $ciPlanFilePath))

}

function Save-CIPlan(
[psobject]$CIPlan,
[string]
[Parameter(
    ValueFromPipeline=$true,
    ValueFromPipelineByPropertyName=$true)]
$ProjectRootDirPath = '.'){
    <#
        .SUMMARY
        an internal utility function to save a runtime CIPlan object as 
        a CIPlan file.
    #>
    
    $ciPlanFilePath = Resolve-Path "$ProjectRootDirPath\CIPlan\CIPlanArchive.json"    
    Set-Content $ciPlanFilePath -Value (ConvertTo-CIPlanArchiveJson -CIPlan $CIPlan)
}

function Add-CIStep(
[string][Parameter(Mandatory=$true)]$Name,
[string][Parameter(Mandatory=$true)]$ModulePath,

[string]
[Parameter(
    ValueFromPipeline=$true,
    ValueFromPipelineByPropertyName=$true)]
$ProjectRootDirPath = '.'){

    $ciPlan = Get-CIPlan -ProjectRootDirPath $ProjectRootDirPath
    
    if($ciPlan.Steps.Contains($Name)){

        throw "A ci step with name $Name already exists.`n Tip: You can remove the existing step by invoking Remove-CIStep"
            
    }
    else{
        
        # add step to plan
        $ciPlan.Steps.Add($Name, [PSCustomObject]@{'Name'=$Name;'ModulePath'=$ModulePath})
        Save-CIPlan -CIPlan $ciPlan -ProjectRootDirPath $ProjectRootDirPath    

    }
}

function Remove-CIStep(
[string][Parameter(Mandatory=$true)]$Name,
[switch]$Force,
[string]
[Parameter(
    ValueFromPipeline=$true,
    ValueFromPipelineByPropertyName=$true)]
$ProjectRootDirPath = '.'){

    $confirmationPromptQuery = "Are you sure you want to delete the CI step with name $Name`?"
    $confirmationPromptCaption = 'Confirm ci step removal'

    if($Force.IsPresent -or $PSCmdlet.ShouldContinue($confirmationPromptQuery,$confirmationPromptCaption)){

        # remove step from plan
        $ciPlan = Get-CIPlan -ProjectRootDirPath $ProjectRootDirPath
        $ciPlan.Steps.Remove($Name)
        Save-CIPlan -CIPlan $ciPlan -ProjectRootDirPath $ProjectRootDirPath
    }

}

function New-CIPlan(
[string]
[Parameter(
    ValueFromPipeline=$true,
    ValueFromPipelineByPropertyName=$true)]
$ProjectRootDirPath = '.'){
    $ciPlanDirPath = Resolve-Path "$ProjectRootDirPath\CIPlan"

    if(!(Test-Path $ciPlanDirPath)){    
        $templatesDirPath = "$PSScriptRoot\Templates"

        # create a directory for the plan
        New-Item -ItemType Directory -Path $ciPlanDirPath

        # create default files
        Copy-Item -Path "$templatesDirPath\CIPlanArchive.json" $ciPlanDirPath
        Copy-Item -Path "$templatesDirPath\Packages.config" $ciPlanDirPath
    }
    else{        
        throw "CIPlan directory already exists at $ciPlanDirPath. If you are trying to recreate your ci plan from scratch you must invoke Remove-CIPlan first"
    }
}

function Remove-CIPlan(
[switch]$Force,
[string]
[Parameter(
    ValueFromPipeline=$true,
    ValueFromPipelineByPropertyName=$true)]
$ProjectRootDirPath = '.'){
    
    $ciPlanDirPath = Resolve-Path "$ProjectRootDirPath\CIPlan"

    $confirmationPromptQuery = "Are you sure you want to delete the CI plan located at $CIPlanDirPath`?"
    $confirmationPromptCaption = 'Confirm ci plan removal'

    if($Force.IsPresent -or $PSCmdlet.ShouldContinue($confirmationPromptQuery,$confirmationPromptCaption)){
        Remove-Item -Path $ciPlanDirPath -Recurse -Force
    }
}

function Invoke-CIPlan(

[PSCustomObject]
[Parameter(
    ValueFromPipeline=$true,
    ValueFromPipelineByPropertyName=$true)]
$Variables=@{'PoshCIHello'="Hello from Posh-CI!"},

[String]
[Parameter(
    ValueFromPipeline=$true,
    ValueFromPipelineByPropertyName=$true)]
$ProjectRootDirPath='.'){
    
    $ciPlanDirPath = Resolve-Path "$ProjectRootDirPath\CIPlan"
    $ciPlanFilePath = "$ciPlanDirPath\CIPlanArchive.json"
    $packagesFilePath = "$ciPlanDirPath\Packages.config"
    if(Test-Path $ciPlanFilePath){
        EnsureChocolateyInstalled
        choco install $packagesFilePath

        # add variables to session
        $CIPlan = Get-CIPlan -ProjectRootDirPath $ProjectRootDirPath

        foreach($step in $CIPlan.Steps.Values){
            Import-Module (resolve-path $step.ModulePath) -Force
            $Variables | Invoke-CIStep
        }
    }
    else{
        throw "CIPlanArchive.json not found at: $ciPlanFilePath"
    }
}

Export-ModuleMember -Function Invoke-CIPlan,New-CIPlan,Remove-CIPlan,Add-CIStep,Remove-CIStep,Get-CIPlan