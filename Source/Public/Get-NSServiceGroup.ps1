﻿Function Get-NSServiceGroup {
    <#
    .SYNOPSIS
        Get servicegroup objects for Citrix Netscaler
    .PARAMETER Name
        Filter on the name property, wildcards accepted
    .EXAMPLE
        Get-NSservicegroup

        Retrieves all servicegroup objects on the NS
    .EXAMPLE
        Get-NSservicegroup -Name ping*

        Retrieves all servicegroup objects whose name begins with ping
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
        https://github.com/martin9700/PSNetScaler
    #>
    [CmdletBinding()]
    Param (
        [string]$Name = "*"
    )

    #Validate NSSession
    ValidateNSSession

    #Retrieve server data
    Invoke-NSCustomQuery -ResourceType servicegroup | Where ServiceGroupName -like $Name
}