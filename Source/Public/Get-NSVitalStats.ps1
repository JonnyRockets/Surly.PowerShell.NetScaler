Function Get-NSVitalStats {
    <#
    .SYNOPSIS
        Get vital statistics from your NetScaler
    #>
    [CmdletBinding()]
    Param (
        [switch]$Gateway
    )

    #Validate NSSession
    ValidateNSSession

    #Get statistics
    $NSStats = Invoke-NSCustomQuery -QueryType stat -ResourceType ns
    $SSLStats = Invoke-NSCustomQuery -QueryType stat -ResourceType ssl

    [PSCustomObject]@{
        NS = $NSSession.Address
        pktcpuusagepcnt = $NSStats.pktcpuusagepcnt
        memusagepcnt = $NSStats.memusagepcnt
        httprequestsrate = $NSStats.httprequestsrate
        sslnewsessionsrate = $SSLStats.sslnewsessionsrate
    }
}

#Get-NSVitalStats