Function Get-NSObjectList
{
    <#
    .SYNOPSIS
        Get servers on a NetScaler

    .PARAMETER NSSession
        Required session object from Connect-NSSessionCookie

    .PARAMETER ObjectType
        Config or List

    .EXAMPLE
        #Create a session on the NetScaler
            $session = Get-NSSessionCookie -Address "CTX-NS-TST-01"

        #Get all config objects on the NetScaler
            $session | Get-NSObjectList -ObjectType Config

    .EXAMPLE
        #Get stat object list from NetScaler, prompt for creds
            Get-NSObjectList -NSSession $session -ObjectType stat

    .FUNCTIONALITY
        NetScaler

    .LINK
        http://github.com/RamblingCookieMonster/Citrix.NetScaler
    #>
    [CmdletBinding()]
    Param(
        [validateset("config","stat")]
        [string]$ObjectType = "config"
    )

    #Check for $NSSession.Session
    ValidateNSSession

    #Define the URI
    $Uri = "https://$($NSSession.Address)/nitro/v1/$ObjectType/"

    #Build up invoke-Restmethod parameters based on input
    $IRMParam = @{
        Method = "Get"
        URI = $Uri
        WebSession = $NSSession.Session
        ErrorAction = "Stop" 
    }

    #Collect results
    $Result = CallInvokeRESTMethod -IRMParam $IRMParam -AllowHTTPAuth $NSSession.AllowHTTPAuth -ErrorAction Stop
    
    #Expand out the list, or provide full response if we got an unexpected errorcode
    If ($Result)
    {
        If ($Result.errorcode -eq 0)
        {
            $Result | Select -ExpandProperty "$ObjectType`objects" | Select -ExpandProperty objects
        }
        Else
        {
            Write-Error "Something went wrong.  Full Invoke-RESTMethod output: `n"
            $Result
        }
    }
    Else
    {
        Write-Error "Invoke-RESTMethod output was empty.  Try troubleshooting with -verbose switch"
    }
}
