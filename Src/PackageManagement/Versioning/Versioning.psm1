$SemanticVersionRegex = "(?<Major>\d+)\.(?<Minor>\d+)\.(?<Patch>\d+)(?:-(?<PreRelease>[0-9A-Za-z-.]*))?(?:\+(?<Build>[0-9A-Za-z-.]*))?"

function Test-SemanticVersion(
    [string]
    [ValidateNotNullOrEmpty()]
    [Parameter(
        Mandatory=$true,
        ValueFromPipeline=$true)]
    $SemanticVersionString){

    $SemanticVersionString -match $SemanticVersionRegex

}

function ConvertTo-SemanticVersionObject(
    [string]
    [ValidateNotNullOrEmpty()]
    [Parameter(
        Mandatory=$true)]
    $SemanticVersionString){

    <#
        .SYNOPSIS
        creates an object representing a v1.0 & v2.0 semantic version (see: http://semver.org/)
    #>

    $SemanticVersionString -match $SemanticVersionRegex |Out-Null
    $Matches.Remove(0)
    $Matches.Major = [int]$Matches.Major
    $Matches.Minor = [int]$Matches.Minor
    $Matches.Patch = [int]$Matches.Patch

    If($Matches.PreRelease){
        $preReleaseIdentifiers = $Matches.PreRelease.Split('.')|%{if($_ -as [long]){[long]$_}else{[string]$_}}
        $Matches.PreRelease = @{Identifiers=[object[]]$preReleaseIdentifiers}
    }

    $Matches.Clone() | Write-Output
}

function Compare-SemanticVersions(
    
    <#
        .SYNOPSIS
        compares v1.0 & v2.0 semantic versions (see: http://semver.org/)
    #>

    [string]
    $XSemVerString,
    
    [string]
    $YSemVerString){

    $XSemVer = ConvertTo-SemanticVersionObject -SemanticVersionString $XSemVerString
    $YSemVer = ConvertTo-SemanticVersionObject -SemanticVersionString $YSemVerString

    If($XSemVer.Major -ne $YSemVer.Major){
        return $XSemVer.Major - $YSemVer.Major
    }
    ElseIf($XSemVer.Minor -ne $YSemVer.Minor){
        return $XSemVer.Minor - $YSemVer.Minor
    }
    ElseIf($XSemVer.Patch -ne $YSemVer.Patch){
        return $XSemVer.Patch - $YSemVer.Patch
    }

    # per spec: "When major, minor, and patch are equal, a pre-release version has lower precedence than a normal version"
    If(!$XSemVer.PreRelease -and $YSemVer.PreRelease){
        return 1
    }
    ElseIf(!$XSemVer.PreRelease -and !$YSemVer.PreRelease){
        return 0
    }
    ElseIf($XSemVer.PreRelease -and !$YSemVer.PreRelease){
        return -1
    }

    For($i = 0;$i -lt [Math]::Min($XSemVer.PreRelease.Identifiers.Count,$YSemVer.PreRelease.Identifiers.Count);$i++){
        $XIdentifier = $XSemVer.PreRelease.Identifiers[$i]
        $YIdentifier = $YSemVer.PreRelease.Identifiers[$i]
        
        #if x and y numeric
        If(($XIdentifier -is [long]) -and ($YIdentifier -is [long])){
            
            #per spec: "identifiers consisting of only digits are compared numerically"
            $xIdentifierMinusYIdentifier = $XIdentifier - $YIdentifier
            If($xIdentifierMinusYIdentifier -ne 0){
                return $xIdentifierMinusYIdentifier
            }
        }
        #if x or[exclusive] y is numeric
        ElseIf(($XIdentifier -is [long]) -xor ($YIdentifier -is [long])){
        
            #per spec: "Numeric identifiers always have lower precedence than non-numeric identifiers"
            If($XIdentifier -isnot [long]){
                return 1
            }
            Else{
                return -1
            }
        }
        #if x and y both textual
        Else{

            #per spec: "identifiers with letters or hyphens are compared lexically in ASCII sort order"
            If($XIdentifier -gt $YIdentifier){
                return 1
            }
            ElseIf($XIdentifier -lt $YIdentifier){
                return -1
            }
        }
    }

    #per spec: "A larger set of pre-release fields has a higher precedence than a smaller set, if all of the preceding identifiers are equal"
    return $XSemVer.PreRelease.Identifiers.Count - $YSemVer.PreRelease.Identifiers.Count
}

function Get-SortedSemanticVersions(
[string[]]
$InputArray,
[switch]
$Descending){

    <#
        .SYNOPSIS
        sorts v1.0 & v2.0 semantic versions (see: http://semver.org/)
    #>
 
    $counter = 0 
    $compareResultFactor = 1
    if($Descending.IsPresent){
    $compareResultFactor = -1
    }
 
    # $unsorted is the first index of the unsorted region 
    for ($unsorted = 1; $unsorted -lt $InputArray.Count; $unsorted++) 
    { 
        # Next item in the unsorted region 
        $nextItem = $InputArray[$unsorted] 
     
        # Index of insertion in the sorted region 
        $location = $unsorted 
     
        while (($location -gt 0) -and ` 
            (($compareResultFactor *(Compare-SemanticVersions -X $InputArray[$location - 1] -Y $nextItem)) -gt 0)) 
        { 
            $counter++ 
            # Shift to the right 
            $InputArray[$location] = $InputArray[$location - 1] 
            $location-- 
        } 
     
        # Insert $nextItem into the sorted region 
        $InputArray[$location] = $nextItem
    } 

    Write-Output $InputArray
}

Export-ModuleMember -Function @(
                                'Get-SortedSemanticVersions',
                                'Test-SemanticVersion')