
function Get-IndexOfKeyInOrderedDictionary(
[string]
[ValidateNotNullOrEmpty()]
$Key,

[System.Collections.Specialized.OrderedDictionary]
[ValidateNotNullOrEmpty()]
$OrderedDictionary){
    <#
        .SYNOPSIS
        an internal utility function to find the index of a key in an ordered dictionary
    #>

    $indexOfKey = -1
    $keysArray = [string[]]$OrderedDictionary.Keys
    for ($i = 0; $i -lt $OrderedDictionary.Count; $i++){
        if($keysArray[$i] -eq $Key){
            $indexOfKey = $i
            break
        }
    }

Write-Output $indexOfKey
}

Export-ModuleMember -Function Get-IndexOfKeyInOrderedDictionary