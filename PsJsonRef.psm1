function Get-JsonRefValue
{
    [CmdletBinding()]
    param(
        [PSCustomObject]$Json,
        [string]$Ref
    )
    $psRef = "`$Json$($Ref -replace '#?\/([^\/]+)', '.''$1''')"
    Write-Verbose "$Ref -> $psRef"
    Invoke-Expression $psRef
}

function Resolve-JsonRefValue
{
    [CmdletBinding()]
    param(
        [PSCustomObject]$Json
    )
    $json.psobject.Properties | %{
        $obj = $_
        switch ($obj.TypeNameOfValue) {
            'System.Management.Automation.PSCustomObject' {
                # check if custom objects is a reference
                Write-Verbose "PSCustomObject: $obj ($($obj.Name))"
                if ($obj.Value.psobject.Properties.Name -contains '$ref') {
                    Write-Verbose "$obj contains `$ref."
                    Write-Verbose "$($obj.Value.'$ref')"
                    $value = Get-JsonRefValue $Json $($obj.Value.'$ref')
                    Write-Verbose "$obj becomes $value"
                    $obj.Value = $value
                }
                else
                {
                    Write-Verbose "Recursion for $obj"
                    Resolve-JsonRefValue $obj.Value
                }
            }
            'System.Object[]' {
                Write-Verbose "Object[]: $obj ($($obj.Name))"
                $replacements = @()
                $arrIdx = -1
                $obj.Value | %{
                    $arrIdx++
                    if ($_.psobject.Properties.Name -contains '$ref') {
                        $value = Get-JsonRefValue $Json $($_.'$ref')
                        Write-Verbose "$_ [$arrIdx] should become $value"
                        $replacements += @{'Index' = $arrIdx; 'Value' = $value}
                    }
                }
                $replacements | %{
                    Write-Verbose "Setting $($obj.Value[$_.Index]) to $($_.Value)"
                    $obj.Value[$_.Index] =$_.Value
                }
            }
            Default {
                Write-Verbose "$($_): $obj"
            }
        } 
    }
}