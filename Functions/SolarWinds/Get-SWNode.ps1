Function Get-SWNode {
    [CmdletBinding()]
    param
    (
        $ComputerName,
        $swServer,
        $CustomProperties
    )
    $swis = Connect-Swis -Hostname $swServer -Trusted
    $NodeIDCheck = (get-orionNodeID -SwisConnection $swis -NodeName $ComputerName)
    
    if ($NodeIDCheck) {
        if ($CustomProperties -eq "True") {
            Get-OrionNode -SwisConnection $swis -NodeID $NodeIDCheck -customproperties
        }
        Else {
            Get-OrionNode -SwisConnection $swis -NodeID $NodeIDCheck
        }
    }
    Else {
        Write-host "$ComputerName not found" -ForegroundColor Red
    }
}