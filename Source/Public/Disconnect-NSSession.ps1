Function Disconnect-NSSession {
    <#
    .SYNOPSIS
        Remove the NSSession variable
    .LINK
        https://github.com/martin9700/PSNetScaler
    #>

    If ($Global:NSSession)
    {
        Clear-Variable -Name NSSession -Scope Global
    }
}