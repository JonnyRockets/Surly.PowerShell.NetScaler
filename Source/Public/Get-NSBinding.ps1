Function Get-NSBinding {
    <#
    .SYNOPSYS
        Retrieve the bindings of NS objects
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