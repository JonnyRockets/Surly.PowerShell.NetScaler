Function ValidateNSSession {
    <#
    #>
    $Properties = $NSSession | Get-Member -MemberType NoteProperty | Select -ExpandProperty Name
    ForEach ($Prop in "Session","Enumeration")
    {
        If ($Properties -notcontains $Prop)
        {
            Write-Error "No connection with an NS has been established.  Run Connect-NSSession to create a session." -ErrorAction Stop
        }
    }
}