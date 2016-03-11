Function Connect-NSSession
{
    <#
    .SYNOPSIS
        Create a session on a NetScaler

    .DESCRIPTION
        Create a session on a NetScaler

    .PARAMETER Address
        Hostname for the NetScaler

    .PARAMETER Credential
        PSCredential object to authenticate with NetScaler.  Prompts if you don't provide one.

    .PARAMETER Timeout
        Timeout for session in seconds

    .PARAMETER AllowHTTPAuth
        Allow HTTP.  Don't specify this uless you want authentication data to potentially be sent in clear text

    .PARAMETER TrustAllCertsPolicy
        Sets your [System.Net.ServicePointManager]::CertificatePolicy to trust all certificates.  Remains in effect for the rest of the session.  See .\Functions\Set-TrustAllCertsPolicy.ps1 for details.  On by default

    .FUNCTIONALITY
        NetScaler

    .EXAMPLE
        #Get a session cookie for CTX-NS-TST-02
            $NSSession = Connect-NSSession -Address ctx-ns-tst-02

    .LINK
        http://github.com/RamblingCookieMonster/Citrix.NetScaler
    #>
    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory=$true)]
        [string]$Address,
        [System.Management.Automation.PSCredential]$Credential = $( Get-Credential -Message "Provide credentials for $Address" ),
        [int]$Timeout = 3600,
        [switch]$AllowHTTPAuth,
        [bool]$TrustAllCertsPolicy = $true
    )

    If ($TrustAllCertsPolicy)
    {
        SetTrustAllCertsPolicy
    }

    #Define the URI
    $Uri = "https://$Address/nitro/v1/config/login/"
    
    #Build the login json
    $jsonCred = @"
{
    "login":  {
                  "username":  "$($Credential.UserName)",
                  "password":  "$($Credential.GetNetworkCredential().Password)",
                  "timeout": $timeout
              }
}
"@

    #Build parameters for Invoke-RESTMethod
    $IRMParam = @{
        Uri = $Uri
        Method = "Post"
        Body = $jsonCred
        ContentType = "application/json"
        SessionVariable = "sess"
    }
    $ConnectProtocol = "https"
    
    #Invoke the REST Method to get a cookie using 'SessionVariable'
    Write-Verbose "Running Invoke-RESTMethod with these parameters:`n$($IRMParam | Format-Table -AutoSize -wrap | Out-String)"
    $cookie = $null
    $cookie = Try
    {
        Invoke-RestMethod @IRMParam
    }
    
    Catch
    {
        Write-Warning "Error calling Invoke-RESTMethod.  Fall back to HTTP=$AllowHTTPAuth. Error details: $_"
        if($AllowHTTPAuth)
        {
            Try
            {
                Write-Verbose "Reverting to HTTP"
                $IRMParam["URI"] = $IRMParam["URI"] -replace "^https","http"
                $ConnectProtocol = "http"
                Invoke-RestMethod @IRMParam
            }
            Catch
            {
                Throw "Fallback to HTTP Failed: $_"
            }
        }
    }

    If ($Cookie)
    {
        #If we got a session variable, return it.  Otherwise, display the results in a warning
        If ($sess)
        {
            #Provide feedback on expiration
            $Date = (Get-Date).AddSeconds($Timeout)
            Write-Verbose "Cookie set to expire in '$Timeout' seconds, at $Date"
            $sess | Add-Member -MemberType NoteProperty -Name ConnectProtocol -Value $ConnectProtocol

            #Now check if server is Primary
            If (($sess | GetNSisPrimary -Address $Address -ConnectProtocol $ConnectProtocol))
            {
                $Primary = $true
            }
            Else
            {
                Write-Warning "$Address is not primary in the HA pair, configuration will not be allowed"
                $Primary = $false
            }
            $Global:NSSession = [PSCustomObject]@{
                Session = $sess
                Address = $Address
                ConnectProtocol = $ConnectProtocol
                Primary = $Primary
                Enumeration = @()
            }
            $Global:NSSession.Enumeration += Get-NSObjectList -ObjectType config
            $Global:NSSession.Enumeration += Get-NSObjectList -ObjectType stat
        }
        Else
        {
            Write-Warning "No session created.  Invoke-RESTMethod output:`n$( $Cookie | Format-Table -AutoSize -Wrap | Out-String )"
        }
    }
    Else{
        Write-Error "Invoke-RESTMethod output was empty.  Try troubleshooting with -verbose switch"
    }
}


