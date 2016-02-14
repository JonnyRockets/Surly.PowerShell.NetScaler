cd C:\Dropbox\github\Citrix.NetScaler\Citrix.NetScaler
If (-not $c)
{
    $c = Get-Credential
}

Remove-Module Citrix.NetScaler
Import-Module .\Citrix.NetScaler.psd1


Connect-NSSession -Address nsmpx-13.athenahealth.com -Credential $c #-Verbose
#Get-NSServer spweb101 | Get-NSBinding

$cpu = Invoke-NSCustomQuery -QueryType stat -ResourceType systemcpu
$mem = Invoke-NSCustomQuery -QueryType stat -ResourceType systemmemory
Invoke-NSCustomQuery -QueryType stat -ResourceType systemsession -Action show
