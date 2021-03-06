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
        [Parameter(
            ValueFromPipeline=$true,
            Mandatory=$true,
            ParameterSetName="Sess")]
        [Microsoft.PowerShell.Commands.WebRequestSession]$Session,

        [Parameter(
            Mandatory=$true,
            ParameterSetName="Sess")]
        [string]$Address,

        [Parameter(
            Mandatory=$true,
            ParameterSetName="Sess")]
        [ValidateSet("http","https")]
        [string]$ConnectProtocol
    )

    PROCESS {
        #Define session object based on default $NSSession or supplied as parameters
        If ($PSCmdlet.ParameterSetName -eq "None")
        {
            $ThisSession = [PSCustomObject]@{
                Session = $NSSession.Session
                Address = $NSSession.Address
                ConnectProtocol = $NSSession.ConnectProtocol
            }
        }
        Else
        {
            $ThisSession = [PSCustomObject]@{
                Session = $Session
                Address = $Address
                ConnectProtocol = $ConnectProtocol
            }
        }
        
        #Define the URI
        $Uri = "$($ThisSession.ConnectProtocol)://$($ThisSession.Address)/nitro/v1/stat/ns/"
    
        #Build up invoke-Restmethod parameters based on input
        $IRMParam = @{
            Method = "Get"
            URI = $Uri
            WebSession = $ThisSession.Session
            ErrorAction = "Stop" 
        }

        #Collect Results
        $Result = $null
        $Result = Invoke-RestMethod @IRMParam

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


Function NSCustomizeObject {
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory=$true)]
        [string]$ResourceType,

        [Parameter(Mandatory=$true)]
        [object[]]$Resource
    )

    #Define default views
    $DefaultView = @{
        "server"        = @("Name","IPAddress")
        "lbmonitor"     = @("Name","Type")
        "service"       = @("Name","ServerName","ServiceType","Port","SvrState")
        "servicegroup"  = @("Name","ServiceType","ServiceGroupEffectiveState")
        "lbvserver"     = @("Name","IPv46","ServiceType","EffectiveState")
        "csvserver"     = @("Name","IPv46","ServiceType","Port")
    }

    ForEach ($Output in $Resource)
    {
        #Normalize Name of the service to Name property
        Switch ($ResourceType)
        {
            "lbmonitor"     { $Output = $Output | Select @{Name="Name";Expression={ $_.MonitorName }},* -ExcludeProperty MonitorName; Break }
            "servicegroup"  { $Output = $Output | Select @{Name="Name";Expression={ $_.servicegroupname }},* -ExcludeProperty servicegroupname; Break }
        }

        #Add default object view for readability
        If ($DefaultView[$ResourceType])
        {
            $Output | Add-Member MemberSet PSStandardMembers ([System.Management.Automation.PSMemberInfo[]]@(New-Object System.Management.Automation.PSPropertySet("DefaultDisplayPropertySet",[String[]]@($DefaultView[$ResourceType]))))
        }
        #Add ResourceType to object, used in later functions
        $Output | Add-Member -MemberType NoteProperty -Name ResourceType -Value $ResourceType

        Write-Output $Output
    }
}


Function SetTrustAllCertsPolicy {
    <#
    .SYNOPSIS
        Set CertificatePolicy to trust all certs.  This will remain in effect for this session.
    .Functionality
        Web
    .NOTES
        Not sure where this originated.  A few references:
            http://connect.microsoft.com/PowerShell/feedback/details/419466/new-webserviceproxy-needs-force-parameter-to-ignore-ssl-errors
            http://stackoverflow.com/questions/11696944/powershell-v3-invoke-webrequest-https-error
    #>
    [cmdletbinding()]
    param()
    
    if([System.Net.ServicePointManager]::CertificatePolicy.ToString() -eq "TrustAllCertsPolicy")
    {
        Write-Verbose "Current policy is already set to TrustAllCertsPolicy"
    }
    else
    {
        add-type @"
            using System.Net;
            using System.Security.Cryptography.X509Certificates;
            public class TrustAllCertsPolicy : ICertificatePolicy {
                public bool CheckValidationResult(
                    ServicePoint srvPoint, X509Certificate certificate,
                    WebRequest request, int certificateProblem) {
                    return true;
                }
            }
"@
    
        [System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustAllCertsPolicy
    }
}


Function ValidateNSSession {
    <#
    #>
    $Properties = $NSSession | Get-Member -MemberType NoteProperty | Select -ExpandProperty Name
    ForEach ($Prop in "Session","Enumeration")
    {
        If ($Properties -notcontains $Prop)
        {
            Throw "No connection with an NS has been established.  Run Connect-NSSession to create a session."
        }
    }
}


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


Function Get-NSBinding {
    <#
    .SYNOPSYS
        Retrieve the bindings of NS objects
    .LINK
        https://github.com/martin9700/PSNetScaler
    #>
    [CmdletBinding()]
    Param (
        [Parameter(ValueFromPipelineByPropertyName=$true,Mandatory=$true)]
        [string]$Name,

        [Parameter(ValueFromPipelineByPropertyName=$true,Mandatory=$true)]
        [string]$ResourceType
    )

    Begin {
        #Validate valid NSSession is available
        ValidateNSSession

        #Define returned property (of course they're not the same across objects)
        $BindingProperty = @{
            "csvserver" = @("csvserver_cspolicy_binding")
            "server" = @("server_service_binding;service","server_servicegroup_binding;servicegroup")
        }
    }

    Process {
        $Data = Invoke-NSCustomQuery -ResourceType "$ResourceType`_binding" -ResourceName $Name

        If ($BindingProperty.ContainsKey($ResourceType))
        {
            ForEach ($ServiceType in $BindingProperty[$ResourceType])
            {
                $Binding,$BoundResourceType = $ServiceType.Split(";")
                If ($Data | Get-Member -Name $Binding)
                {
                    NSCustomizeObject -ResourceType $BoundResourceType -Resource ($Data | Select -ExpandProperty $Binding)
                }
            }
        }
        Else
        {
            $Data | Select * -ExcludeProperty ResourceType
        }
    }
}


Function Get-NSCSvServer {
    <#
    .SYNOPSIS
        Get CSvServer objects for Citrix Netscaler
    .PARAMETER Name
        Filter on the name property, wildcards accepted
    .EXAMPLE
        Get-NSCSvServer

        Retrieves all CSvServer objects on the NS
    .EXAMPLE
        Get-NSCSvServer -Name ping*

        Retrieves all CSvServer objects whose name begins with ping
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
    Invoke-NSCustomQuery -ResourceType csvserver | Where Name -like $Name
}


Function Get-NSLBvServer {
    <#
    .SYNOPSIS
        Get lbvserver objects for Citrix Netscaler
    .PARAMETER Name
        Filter on the name property, wildcards accepted
    .EXAMPLE
        Get-NSlbvserver

        Retrieves all lbvserver objects on the NS
    .EXAMPLE
        Get-NSlbvserver -Name ping*

        Retrieves all lbvserver objects whose name begins with ping
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
    Invoke-NSCustomQuery -ResourceType lbvserver | Where Name -like $Name
}


Function Get-NSMonitor {
    <#
    .SYNOPSIS
        Get monitor objects for Citrix Netscaler
    .PARAMETER Name
        Filter on the name property, wildcards accepted
    .EXAMPLE
        Get-NSMonitor

        Retrieves all monitor objects on the NS
    .EXAMPLE
        Get-NSMonitor -Name ping*

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
        https://github.com/martin9700/PSNetScaler
    #>
    [CmdletBinding()]
    Param (
        [string]$Name = "*"
    )

    #Validate NSSession
    ValidateNSSession

    #Retrieve server data
    Invoke-NSCustomQuery -ResourceType lbmonitor | Where MonitorName -like $Name
}


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
    $Uri = "$($NSSession.ConnectProtocol)://$($NSSession.Address)/nitro/v1/$ObjectType/"

    #Build up invoke-Restmethod parameters based on input
    $IRMParam = @{
        Method = "Get"
        URI = $Uri
        WebSession = $NSSession.Session
        ErrorAction = "Stop" 
    }

    #Collect results
    $Result = Invoke-RestMethod @IRMParam
    
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


Function Get-NSServer {
    <#
    .SYNOPSIS
        Get server objects for Citrix Netscaler
    .PARAMETER Name
        Filter on the name property, wildcards accepted
    .EXAMPLE
        Get-NSServer

        Retrieves all server objects on the NS
    .EXAMPLE
        Get-NSServer -Name ping*

        Retrieves all server objects whose name begins with ping
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
        [string]$Name
    )

    #Validate NSSession
    ValidateNSSession

    #Retrieve server data
    Invoke-NSCustomQuery -ResourceType server -FilterTable @{Name=$Name}
}


Function Get-NSService {
    <#
    .SYNOPSIS
        Get service objects for Citrix Netscaler
    .PARAMETER Name
        Filter on the name property, wildcards accepted
    .EXAMPLE
        Get-NSservice

        Retrieves all service objects on the NS
    .EXAMPLE
        Get-NSService -Name ping*

        Retrieves all service objects whose name begins with ping
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
    Invoke-NSCustomQuery -ResourceType service | Where Name -like $Name
}


Function Get-NSServiceGroup {
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


Function Invoke-NSCustomQuery {
    <#
    .SYNOPSIS
        Execute a custom query against a Citrix NetScaler

    .DESCRIPTION
        Execute a custom query against a Citrix NetScaler

        This function builds up a URI and other details for an Invoke-RESTMethod call against a Citrix NetScaler

        Use Verbose output for details (e.g. to view the final Invoke-RESTMethod parameters)

        This is a work in progress function.  Please be sure to run it with -whatif to verify it builds your Invoke-RESTMethod call correctly.

    .PARAMETER Address
        Hostname or IP for the NetScaler

    .PARAMETER Credential
        PSCredential object to authenticate with NetScaler.  Prompts if you don't provide one.

    .PARAMETER WebSession
        If specified, use an existing web session rather than an explicit credential

    .PARAMETER QueryType
        Query type.  Valid options are 'config' and 'stat'.  See list parameter

    .PARAMETER List
        If this switch is specified, provide a list of all valid objects for specified QueryType

    .PARAMETER ResourceType
        Type of object to query for

    .PARAMETER ResourceName
        Name of an object to query for

    .PARAMETER Argument
        If specified, the argument for a query

    .PARAMETER FilterTable
        If specified, use this hashtable of attribute/value pairs to filter results.  Examples:
            @{ipv46="1.1.1.1"}
            @{state="ENABLED";ipv46="1.1.1.1"}

    .PARAMETER Raw
        Provide direct results from Invoke-RESTMethod

    .PARAMETER Method
        This is directly mapped to the same parameter on Invoke-RESTMethod.  Get-Help Invoke-RESTMethod -full for more details

    .PARAMETER ContentType
        This is directly mapped to the same parameter on Invoke-RESTMethod.  Get-Help Invoke-RESTMethod -full for more details

    .PARAMETER Body
        This is directly mapped to the same parameter on Invoke-RESTMethod.  Get-Help Invoke-RESTMethod -full for more details

    .PARAMETER Headers
        This is directly mapped to the same parameter on Invoke-RESTMethod.  Get-Help Invoke-RESTMethod -full for more details

    .PARAMETER Action
        Action to run.  Example:  Disable.

    .PARAMETER AllowHTTPAuth
        Allow HTTP.  Don't specify this uless you want authentication data to potentially be sent in clear text

    .PARAMETER TrustAllCertsPolicy
        Sets your [System.Net.ServicePointManager]::CertificatePolicy to trust all certificates.  Remains in effect for the rest of the session.  See .\Functions\Set-TrustAllCertsPolicy.ps1 for details.  On by default

    .EXAMPLE
        #Return details on lbvservers from CTX-NS-TST-01 where IPV46 is "1.1.1.1"
            Invoke-NSCustomQuery -Address "CTX-NS-TST-01" -ResourceType "lbvserver" -FilterTable @{ipv46="1.1.1.1"}
    
    .EXAMPLE
        #Return all enabled servers on CTX-NS-TST-01
            Invoke-NSCustomQuery -Address "CTX-NS-TST-01" -ResourceType "server" -FilterTable @{state="ENABLED"}
        #Return all disabled servers on CTX-NS-TST-01
            Invoke-NSCustomQuery -Address "CTX-NS-TST-01" -ResourceType "server" -FilterTable @{state="DISABLED"}
    
    .EXAMPLE
        #Return details on lbvserver with name SomeLBVServer from CTX-NS-TST-01
            Invoke-NSCustomQuery -Address "CTX-NS-TST-01" -ResourceType "lbvserver" -ResourceName "SomeLBVServer"

    .EXAMPLE
        #List available 'config' objects we can query.  lbvserver, server, service and servicegroup are a few examples:
            Invoke-NSCustomQuery -Address CTX-NS-TST-01 -QueryType config -list -Credential $cred

        #pull the same list for the stat objects
            Invoke-NSCustomQuery -Address CTX-NS-TST-01 -QueryType stat -list -Credential $cred

    .EXAMPLE

        #Pull all lbvservers, servers, services, servicegroups from ctx-ns-tst-01
            Invoke-NSCustomQuery -Address "CTX-NS-TST-01" -ResourceType "lbvserver" -Credential $cred
            Invoke-NSCustomQuery -Address "CTX-NS-TST-01" -ResourceType "server" -Credential $cred
            Invoke-NSCustomQuery -Address "CTX-NS-TST-01" -ResourceType "service" -Credential $cred
            Invoke-NSCustomQuery -Address "CTX-NS-TST-01" -ResourceType "servicegroup" -Credential $cred

    .EXAMPLE

        #These two queries pull the same information.  Invoke-NSCustomQuery provides the data, but does not help parsing the results or validating vserver:
            #Get-NSLBVServerBinding -Address CTX-NS-TST-01 -VServer "SomeValidVServerName" -Credential $cred
            Invoke-NSCustomQuery -Address "CTX-NS-TST-01" -ResourceType "lbvserver_binding" -Argument "SomeValidVServerName" -Credential $cred

    .EXAMPLE
        
    #This example illustrates how to disable a server.  Note that this does not save changes!

        #Build the JSON for a server you want to disable
$json = @"
{
    "server": {
        "name":"SomeServerName"
    }
}
"@

        #Create a session on CTX-NS-TST-01
            $session = Get-NSSessionCookie -Address ctx-ns-tst-01 -AllowHTTPAuth

        #use that session to disable a server
            Invoke-NSCustomQuery -Address "CTX-NS-TST-01" -ResourceType "server" -method Post -Body $json -ContentType application/vnd.com.citrix.netscaler.server+json -AllowHTTPAuth -action disable -verbose -WebSession $session
            #Note that an error will be returned indicating null output.  Not sure how else to handle this, as null output is usually bad.  Will work on it...
            
        #verify the change:
            Invoke-NSCustomQuery -Address CTX-NS-TST-01 -ResourceType server -ResourceName SomeServerName -Credential $cred -AllowHTTPAuth

    .NOTES
        There isn't much detail out there about using this API with PowerShell.  I suspect this wrapper will be limited in the calls it can make.
        
        A few resources for further reading:
            http://blogs.citrix.com/2011/08/05/nitro-apis-fun-over-http/
            http://support.citrix.com/proddocs/topic/netscaler-main-api-10-map/ns-nitro-rest-landing-page-con.html
            http://support.citrix.com/servlet/KbServlet/download/30602-102-681756/NS-Nitro-Gettingstarted-guide.pdf

    .FUNCTIONALITY
        NetScaler

    .LINK
        http://github.com/RamblingCookieMonster/Citrix.NetScaler

    #>
    [CmdletBinding(
        DefaultParameterSetName='SimpleQuery',
        SupportsShouldProcess=$true,
        ConfirmImpact='High'
    )]
    Param (
        [validateset("config","stat")]
        [string]$QueryType="config",

        [Parameter( ParameterSetName='List' )]
        [switch]$List,

        [Parameter( ParameterSetName='SimpleQuery' )]
        [Parameter( ParameterSetName='AdvancedQuery' )]
        [ValidateScript({
            If ($Global:NSSession.Enumeration -contains $_)
            {
                $true
            }
        })]
        #[validatescript({$_ -notmatch "\W"})]
        [string]$ResourceType = $null,

        [Parameter( ParameterSetName='SimpleQuery' )]
        [Parameter( ParameterSetName='AdvancedQuery' )]
        [string]$ResourceName = $null,
    
        [Parameter( ParameterSetName='SimpleQuery' )]
        [Parameter( ParameterSetName='AdvancedQuery' )]
        [validatescript({$_ -notmatch "\W"})]
        [string]$Argument = $null,

        [Parameter( ParameterSetName='SimpleQuery' )]
        [Parameter( ParameterSetName='AdvancedQuery' )]
        [validatescript({
            #We don't want any non word characters as a key...
            #values are harder to test, e.g. could be an IP...
            foreach($key in $_.keys){
                if($key -match "\W"){
                    Throw "`nError:`n`FilterTable contains key '$key' with a non-word character"
                }
            }
            $true
        })]
        [System.Collections.Hashtable]$FilterTable = $null,
    
        [Parameter()]
        [switch]$Raw,

        [Parameter( ParameterSetName='AdvancedQuery' )]
        [Microsoft.PowerShell.Commands.WebRequestMethod]$Method = "Get",

        [Parameter( ParameterSetName='AdvancedQuery' )]
        [string]$ContentType = $null,

        [Parameter( ParameterSetName='AdvancedQuery' )]
        [string]$Body = $null,

        [Parameter( ParameterSetName='AdvancedQuery' )]
        [string]$Headers = $null,

        [Parameter( ParameterSetName='AdvancedQuery' )]
        [string]$Action = $null
    )

    #Define the URI
    $Uri = "$($NSSession.ConnectProtocol)://$($NSSession.Address)/nitro/v1/$($QueryType.tolower())/"
    
    #Build up the URI for non-list queries
    If (-not $List)
    {
        
        #Add the resource type
        If ($ResourceType)
        {
            Write-Verbose "Added ResourceType $ResourceType to URI"
            $Uri += "$($ResourceType.tolower())/"
            
            #Allow a resourcename to be specified
            If ($ResourceName)
            {
                Write-Verbose "Added ResourceName $ResourceName to URI"
                $Uri += "$($ResourceName.tolower())/"
            }
            #Add an argument (e.g. a valid lbvserver for lbvserver_binding resource)
            ElseIf ($Argument)
            {
                Write-Verbose "Added Argument $Argument to URI"
                $Uri += "$Argument"
            }
        }

        #Create a filter string from the provided hash table
        if($FilterTable)
        {
            $Uri = $Uri.TrimEnd("/")
            $Uri += "?filter="
            $Uri += $(
                ForEach ($Key in $FilterTable.Keys)
                {
                    "$Key`:$($FilterTable[$Key])"
                }
            ) -join ","
        }
        ElseIf ($Action)
        {
            $Uri = $Uri.TrimEnd("/")
            #Add tolower()?
            $Uri += "?action=$Action"
        }
    }

    #Build up invoke-Restmethod parameters based on input
    $IRMParam = @{
        Method = $Method
        URI = $Uri
        WebSession = $NSSession.Session
        ErrorAction = "Stop"
    }
    If($ContentType)
    {
        $IRMParam.add("ContentType",$ContentType)
    }
    If($Body)
    {
        $IRMParam.add("Body",$Body)
    }
    If($Headers)
    {
        $IRMParam.add("Headers",$Headers)
    }

    Write-Verbose "Invoke-RESTMethod params: $($IRMParam | Format-Table -AutoSize -wrap | out-string)"
    
    #Invoke the REST Method
    If ($PsCmdlet.ParameterSetName -eq "AdvancedQuery")
    {
        If ($PsCmdlet.ShouldProcess("IRM Parameters:`n $($IRMParam | Format-Table -AutoSize -wrap | out-string)", "Invoke-RESTMethod with the following parameters"))
        {
            $Result = Invoke-RestMethod @IRMParam
        }
        Else
        {
            break
        }
    }
    Else
    {
        $Result = Invoke-RestMethod @IRMParam
    }

    #Display the results
    If ($Result)
    {
        If ($Raw)
        {
            #user wants raw output from invoke-restmethod
            $Result
        }
        ElseIf ($List)
        {
            #list parameterset, expand the properties!
            $Result | select -ExpandProperty "$QueryType`objects" | select -ExpandProperty objects
        }
        ElseIf ($ResourceType)
        {
            If ($Result.$ResourceType){
                #expand the resourcetype
                NSCustomizeObject -ResourceType $ResourceType -Resource ($Result | select -ExpandProperty $ResourceType -ErrorAction stop)
            }
            ElseIf ($Result.errorcode -ne 0)
            {
                Write-Error "Result did not have expected property '$ResourceType' and errorcode mismatch.  Invoke-RESTMethod output:`n"
                $Result
            }
        }
    }
    Else
    {
        Write-Error "Invoke-RESTMethod output was empty.  Try troubleshooting with -verbose switch"
    }
}


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


#Included Statements:


