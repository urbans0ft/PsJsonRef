function Get-JsonRefValue
{
    [CmdletBinding(DefaultParameterSetName='ref-only')]
    param(
        [Parameter(Mandatory,Position=0,ParameterSetName='ref-only')]
        [Parameter(Mandatory,Position=0,ParameterSetName='ref-from-obj')]
        [string]$Ref,
        [Parameter(Mandatory,Position=1,ParameterSetName='ref-from-obj')]
        [PSCustomObject]$Json
    )
    if (-Not ($Ref -match '^(?<file>[^#]*)(?<ref>#.*)$')) {
        throw "'$Ref does not match regex.'"
    }
    $file   = $Matches['file']
    $relRef = $Matches['ref']
    if ($PSCmdlet.ParameterSetName -eq 'ref-only') {
        
        if ([string]::IsNullOrEmpty($file)) {
            throw "`$Ref does not contain a file name."
        }
        if (-Not ([System.IO.File]::Exists($file))) {
            throw "File '$file' not found!"
        }
        $Json = Get-Content $file -Raw | ConvertFrom-Json
    }
    Write-Verbose "JSON: $Json"
    $psRef = "`$Json$($relRef -replace '#?\/([^\/]+)', '.''$1''')"
    Write-Verbose "$Ref -> $psRef"
    $value = Invoke-Expression $psRef
    Write-Verbose "Invoke-Expression `$psRef => $value"
    $value
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
                    $value = Get-JsonRefValue $($obj.Value.'$ref')
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
                        $value = Get-JsonRefValue $($_.'$ref')
                        Write-Verbose "$_ [$arrIdx] should become $value"
                        $replacements += @{'Index' = $arrIdx; 'Value' = $value}
                    }
                    else
                    {
                        Write-Verbose "Recursion for $_"
                        Resolve-JsonRefValue $_
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