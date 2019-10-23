Function Remove-SWNode {
    [CmdletBinding()]
    param
    (
        $ComputerName,
        $swServer
    )

    $swis = Connect-Swis -Hostname $swServer -Trusted
    $ComputerName | ForEach-Object {
        $NodeID = (get-orionNodeID -SwisConnection $swis -NodeName $ComputerName)
        if ($NodeID) {
            Remove-OrionNode -SwisConnection $swis -NodeID $NodeID
            Write-host "System $ComputerName with NodeID of $NodeID has been removed." -ForegroundColor Green
        }
        Else {
            Write-host "$ComputerName not found." -ForegroundColor Red
        }
    }
}