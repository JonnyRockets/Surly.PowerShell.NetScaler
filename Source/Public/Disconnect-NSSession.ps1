Function Disconnect-NSSession {
    <#
    .SYNOPSIS
        Remove the NSSession variable
    .LINK
        https://github.com/martin9700/PSNetScaler
    #>

    
    If ($Global:NSSession)
    {
        #Define the URI
        $Uri = "$($NSSession.ConnectProtocol)://$($NSSession.Address)/nitro/v1/config/logout/"

        #Build the logout json
        $jsonLogout = @"
{
    "logout":{}
}
"@

        #Build parameters for Invoke-RESTMethod
        $IRMParam = @{
            Uri         = $Uri
            Method      = "Post"
            Body        = $jsonLogout
            ContentType = "application/vnd.com.citrix.netscaler.logout+json"
            WebSession  = $NSSession.Session
            ErrorAction = "Stop"
        }

        Try {
            Invoke-RestMethod @IRMParam
            Clear-Variable -Name NSSession -Scope Global
        }
        Catch {
            Write-Error "Problem logging out of $($NSSession.Address) because ""$_"""
        }
    }
    Else
    {
        Write-Verbose "You are not currently logged into a NetScaler" -Verbose
    }
}



