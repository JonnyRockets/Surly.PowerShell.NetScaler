Function Get-NSPatSet {
    <#
    .SYNOPSIS
        Get Pattern Sets from NetScaler
    .PARAMETER Name
        Filter on the name property, wildcards accepted
    .EXAMPLE
        Get-NSPatSet

        Retrieves all monitor objects on the NS
    .EXAMPLE
        Get-NSPatSet -Name ping*

        Retrieves all monitor objects whose name begins with ping
    .NOTES
        Author:             Martin Pugh
        Twitter:            @thesurlyadm1n
        Spiceworks:         Martin9700
        Blog:               www.thesurlyadmin.com
      
        Changelog:
            1.0             Initial Release
    .FUNCTIONALITY
        NetScaler
    .LINK
        https://github.com/martin9700/Surly.PowerShell.NetScaler
    #>
    [CmdletBinding()]
    Param (
        [string]$Name = "*"
    )

    #Validate NSSession
    ValidateNSSession

    #Retrieve PatSet's
    $PatSets = Invoke-NSCustomQuery -ResourceType policypatset | Where Name -like $Name

    #Retrieve associated string
    ForEach ($PatSet in $PatSets)
    {
        $Patterns = Invoke-NSCustomQuery -ResourceType policypatset_binding -ResourceName $PatSet.Name | Select -ExpandProperty policypatset_pattern_binding
        [PSCustomObject]@{
            Name = $PatSet.Name
            Index = $PatSet.Index
            PatternBinding = $Patterns
            String = $Patterns | Select -ExpandProperty String
        }
    }
}