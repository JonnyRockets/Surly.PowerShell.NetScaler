Function GetNSisPrimary {
    <#
    .SYNOPSIS
        Get the current HA state for a NetScaler, used in the Connect-NSSessionCookie function to determine if you are connecting to a primary HA pair

    .PARAMETER NSSession
        Required NSSession object from Connect-NSSessionCookie
    
    .EXAMPLE
        #Create a session on the NetScaler
            $session = Get-NSSessionCookie -Address "CTX-NS-TST-01"

        #$true or $false depending on whether ctx-ns-tst-01 is the primary in an HA cluster
            GetNSisPrimary -NSSession $session

    .FUNCTIONALITY
        NetScaler

    .LINK
        http://github.com/RamblingCookieMonster/Citrix.NetScaler
    #>
    [CmdletBinding(DefaultParameterSetName="None")]
    Param(
        [Parameter(ValueFromPipeline=$true,
            Mandatory=$true,
            ParameterSetName="Sess")]
        [Microsoft.PowerShell.Commands.WebRequestSession]$Session,
        [Parameter(Mandatory=$true,
            ParameterSetName="Sess")]
        [string]$Address,
        [Parameter(Mandatory=$true,
            ParameterSetName="Sess")]
        [bool]$AllowHTTPAuth
    )

    PROCESS {
        #Define session object based on default $NSSession or supplied as parameters
        If ($PSCmdlet.ParameterSetName -eq "None")
        {
            $ThisSession = [PSCustomObject]@{
                Session = $NSSession.Session
                Address = $NSSession.Address
                AllowHTTPAuth = $NSSession.AllowHTTPAuth
            }
        }
        Else
        {
            $ThisSession = [PSCustomObject]@{
                Session = $Session
                Address = $Address
                AllowHTTPAuth = $AllowHTTPAuth
            }
        }
        
        #Define the URI
        $Uri = "https://$($ThisSession.Address)/nitro/v1/stat/ns/"
    
        #Build up invoke-Restmethod parameters based on input
        $IRMParam = @{
            Method = "Get"
            URI = $Uri
            WebSession = $ThisSession.Session
            ErrorAction = "Stop" 
        }

        #Collect Results
        $Result = $null
        $Result = CallInvokeRESTMethod -IRMParam $IRMParam -AllowHTTPAuth $ThisSession.AllowHTTPAuth -ErrorAction Stop

        #Take action depending on -raw parameter and the data in $Result
        If ($Result)
        {
            #Result exists with no error
            If($Result.errorcode -eq 0)
            {
                If ($Result.ns.hacurmasterstate -eq "Primary")
                {
                    $true
                }
                Else
                {
                    $false
                }
            }
            Else
            {
                Write-Error "Something went wrong.  Full Invoke-RESTMethod output: `n"
                Return $Result
            }
        }
        Else
        {
            Write-Error "Invoke-RESTMethod output was empty.  Try troubleshooting with -verbose switch"
        }
    }
}