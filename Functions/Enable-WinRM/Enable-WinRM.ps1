Function Enable-WinRM {
	[CmdletBinding()]
    param 
    ( 
        [String[]]$ComputerName,
        $global:compName = $computerName
    ) 


	$result = winrm id -r:$global:compName 2>$null

	Write-Host	
	if ($LastExitCode -eq 0) {
		Write-Host "WinRM already enabled on" $global:compName "..." -ForegroundColor green
	} else {
		Write-Host "Enabling WinRM on" $global:compName "..." -ForegroundColor red
		$CustomPsExecParameters = '-s C:\Windows\system32\winrm.cmd qc -quiet'
		$CustomPsServiceParameters = 'restart WinRM'
		$CommandString1 = "/accepteula \\$ComputerName $CustomPsExecParameters"
		$CommandString2 = "/accepteula \\$ComputerName $CustomPsServiceParameters"
		$PsExecExecutable = Get-Item -LiteralPath (Join-Path $PSScriptRoot 'PSTools\PsExec.exe')
		$PsServiceExecutable =  Get-Item -LiteralPath (Join-Path $PSScriptRoot 'PSTools\PsService.exe')
		Start-Process -FilePath $PsExecExecutable -ArgumentList $CommandString1 -Wait -NoNewWindow -PassThru -ErrorAction Continue -Debug
		if ($LastExitCode -eq 0) {
			Start-Process -FilePath $PsServiceExecutable -ArgumentList $CommandString2 -Wait -NoNewWindow -PassThru -ErrorAction Continue
			$result = winrm id -r:$global:compName 2>$null
			
			if ($LastExitCode -eq 0) {Write-Host 'WinRM successfully enabled!' -ForegroundColor green}
			else {}
		} 
		else {}
	}
}