PSNetscaler
===========
This is a permanent fork of RamblingCookieMonster's [Citrix.Netscaler](https://github.com/RamblingCookieMonster/Citrix.NetScaler) module.  Warren's new position unfortunately lacks a Netscaler for him to work on, but he has given me permission to permanently fork his code and continue work on it.  

SYNOPSIS
--------
This module is designed to let you work with a Citrix Netscaler from within PowerShell, using the REST API.  To start the project is focused on GETting information out of the Netscaler but the goal is to eventually let you make configuration changes as well.  Because of the vast complexitiy of the product it is doubtful that this project will let you configure everything.  In the future I may implement Open-SSH into this project and allow a more open ended session using CLI commands.


INSTRUCTIONS
------------
1. Download this repo, Unblock the file(s), copy the Citrix.NetScaler folder to an appropriate module location
2. Import-Module pathToRepo\PSNetscaler
3. Get-Command -Module PSNetscaler

	###Connect a session to your Netscaler, call it: nstestmgmt1
		$Session = Connect-NSSession -Address nstestmgmt1 -Credential (Get-Credential)
		#This will create a permanent global variable:  $NSSession
		#Contains web session information
		
    ###This example illustrates how to disable a server and save the NetScaler config
        #Build the JSON for a server you want to disable.  !NOTE! you must not indent this.  Remove all indentation.
        $json = @"
        {
            "server": {
                "name":"SomeServerName"
            }
        }
        "@

    ###Disable the server specified in $json
        Invoke-NSCustomQuery -Address "CTX-NS-TST-01" -ResourceType "server" -method Post -Body $json -ContentType application/vnd.com.citrix.netscaler.server+json -AllowHTTPAuth -action disable -verbose
        #Note that an error will be returned indicating null output.  Not sure how else to handle this, as null output is usually bad.  Will work on it...
            
    ###Verify the change:
        Invoke-NSCustomQuery -Address CTX-NS-TST-01 -ResourceType server -ResourceName SomeServerName -AllowHTTPAuth

    ###Save the config on CTX-NS-TST-01
        Save-NSConfig -Address CTX-NS-TST-01 -AllowHTTPAuth


Contributing to the Project
---------------------------
Please read the CONTRIBUTING.md file for contributing guidelines


TODO Items
----------
1. Get-VitalStats
2. Get-Bindings 
3. Pester test framework
4. Add $NSEnumeration into $NSSession.  Make $NSSession an object with both data.  


		
Further References
------------------
 
* http://blogs.citrix.com/2011/08/05/nitro-apis-fun-over-http/
* http://support.citrix.com/proddocs/topic/netscaler-main-api-10-map/ns-nitro-rest-landing-page-con.html
* http://support.citrix.com/servlet/KbServlet/download/30602-102-681756/NS-Nitro-Gettingstarted-guide.pdf
* http://blogs.citrix.com/2014/02/04/using-curl-with-the-netscaler-nitro-rest-api/
* There is no NetScaler REST API documentation available online.  It is tucked deep in the NetScaler bits.  If you have the bits for 10.1, extract them from here:  build-10.1-119.7_nc.tgz\build_dara_119_7_nc.tar\ns-10.1-119.7-nitro-rest.tgz\ns-10.1-119.7-nitro-rest.tar\ns_nitro-rest_dara_119_7.tar\.  This should be available online at some point...


