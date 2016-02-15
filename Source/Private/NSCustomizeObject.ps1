<#
#>
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