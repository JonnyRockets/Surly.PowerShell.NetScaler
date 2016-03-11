Function Save-NSConfig {
    <#
    .SYNOPSIS
        Saves the running config for a NetScaler

    .PARAMETER Force
        If specified do not check to ensure NetScaler is primary in the HA cluster

        I recall this might not be best practice, but currently if you want to bypass confirmation you need to use -confirm:$false

    .FUNCTIONALITY
        NetScaler

    .LINK
        https://github.com/martin9700/PSNetScaler
    #>
    [CmdletBinding(
        SupportsShouldProcess=$true,
        ConfirmImpact='High'
    )]
    Param(
        [switch]$Force
    )

    #Validate NSSession
    ValidateNSSession

    #Build parameters for Invoke-RESTMethod
    $IRMParam = @{
        Uri = "$($NSSession.ConnectProtocol)://$($NSSession.Address)/nitro/v1/config/nsconfig?action=save"
        Body = ‘{“nsconfig”:{}}’
        Method = 'Post'
        ContentType = 'application/vnd.com.citrix.netscaler.nsconfig+json'
        ErrorAction = 'Stop'
        WebSession = $NSSession.Session
    }
    

    Write-Verbose "$($NSSession.Address) is Primary: $($NSSession.Primary)"

    If($NSSession.Primary -or $Force )
    {
        #Collect Results
        If ($pscmdlet.ShouldProcess($NSSession.Address, "Save running configuration state"))
        {
            $Result = $null
            $Result = Invoke-RestMethod @IRMParam
            
            #Take action depending on -raw parameter and the data in $Result
            If($Result)
            {
                #Result exists with no error
                If($Result.errorcode -ne 0)
                {
                    Write-Error "Something went wrong.  Full Invoke-RESTMethod output: $Result"
                }
            }
            Else
            {
                Write-Verbose "Invoke-RESTMethod output was empty.  This is the expected behavior"
            }
        }
    }
    Else
    {   
        Throw "$($NSSession.Address) is not the primary node.  Pick the Primary node or use the force parameter"
    }
}
