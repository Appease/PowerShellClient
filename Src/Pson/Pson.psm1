Set-Alias ConvertFrom-Pson Invoke-Expression -Description "Convert variable from PSON"

Function ConvertTo-Pson(
[Parameter(
    ValueFromPipeline=$true)]
$InputObject, 
[Int]
$Depth = 9, 
[Int]
$Layers = 1,
[Switch]
$Strict) {
<#
    .LINK http://stackoverflow.com/questions/15139552/save-hash-table-in-powershell-object-notation-pson
#>

    $Format = $Null
    $Quote = If ($Depth -le 0) {""} Else {""""}
    $Space = If ($Layers -le 0) {""} Else {" "}

    If ($InputObject -eq $Null) {"`$Null"} Else {
        
        $Type = "[" + $InputObject.GetType().Name + "]"

        $PSON = If ($InputObject -is [Array]) {
            
            $Format = "@(", ",$Space", ")"
            
            If ($Depth -gt 1) {

                For ($i = 0; $i -lt $InputObject.Count; $i++) {

                    ConvertTo-PSON $InputObject[$i] ($Depth - 1) ($Layers - 1) -Strict:$Strict

                }
            
            }

        } ElseIf ($InputObject -is [Xml]) {

            $Type = "[Xml]"
            $String = New-Object System.IO.StringWriter
            $InputObject.Save($String)
            $Xml = "'" + ([String]$String).Replace("`'", "&apos;") + "'"
            If ($Layers -le 0) {
            
                ($Xml -Replace "\r\n\s*", "") -Replace "\s+", " "

            } ElseIf ($Layers -eq 1) {

                $Xml
            
            } Else {
            
                $Xml.Replace("`r`n", "`r`n`t")
            
            }

            $String.Dispose()

        }ElseIf ($InputObject -is [ScriptBlock]) {
            "{$($InputObject.ToString())}"
        
        } ElseIf ($InputObject -is [DateTime]) {

            "$Quote$($InputObject.ToString('s'))$Quote"
        
        } ElseIf ($InputObject -is [String]) {

            0..11 | ForEach {$InputObject = $InputObject.Replace([String]"```'""`0`a`b`f`n`r`t`v`$"[$_], ('`' + '`''"0abfnrtv$'[$_]))}; "$Quote$InputObject$Quote"
        
        } ElseIf ($InputObject -is [Boolean]) {

            "`$$InputObject"
        
        } ElseIf ($InputObject -is [Char]) {
            
            If ($Strict) {[Int]$InputObject} Else {"$Quote$InputObject$Quote"}

        } ElseIf ($InputObject -is [ValueType]) {

            $InputObject

        } ElseIf ($InputObject -as [Hashtable]){

            if($InputObject -is [System.Collections.Specialized.OrderedDictionary]){              
                $Type = "[Ordered]"  
            }
            
            $Format = "@{", ";$Space", "}"
            
            If ($Depth -gt 1){

                $InputObject.GetEnumerator() | ForEach {"$Quote$($_.Name)$Quote" + "$Space=$Space" + (ConvertTo-PSON $_.Value ($Depth - 1) ($Layers - 1) -Strict:$Strict)}
            
            }
        } ElseIf ($InputObject -is [Object]) {

            $Format = "@{", ";$Space", "}"

            If ($Depth -gt 1) {

                $InputObject.PSObject.Properties | ForEach {$_.Name + "$Space=$Space" + (ConvertTo-PSON $_.Value ($Depth - 1) ($Layers - 1) -Strict:$Strict)}
            
            }
        
        } Else {

            $InputObject
        
        }

        If ($Format) {

            $PSON = $Format[0] + (&{

                If (($Layers -le 1) -or ($PSON.Count -le 0)) {

                    $PSON -Join $Format[1]
                
                } Else {
                
                    ("`r`n" + ($PSON -Join "$($Format[1])`r`n")).Replace("`r`n", "`r`n`t") + "`r`n"
                
                }
            
            }) + $Format[2]
        
        }

        If ($Strict) {
            "$Type$PSON"
        } Else {
            "$PSON"
        }
    }
}

Export-ModuleMember -Function ConvertTo-Pson
Export-ModuleMember -Alias ConvertFrom-Pson
