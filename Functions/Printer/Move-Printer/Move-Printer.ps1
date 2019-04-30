Function Move-Printer {
    [CmdletBinding()]
    param
    (
        $oldPrintServer = (Read-Host "Enter old print server hostname."),
        $newPrintServer = (Read-Host "Enter new print server hostname."),
        $LogDirectory = (Read-Host "Enter path to store the logs.")

    )
    # Nested Logging Function
    Function Write-Log($message, $level = "INFO") {
        $date_stamp = Get-Date -Format s
        $log_entry = "$date_stamp - $level - $message"
        if (-not (Test-Path -Path $LogDirectory)) {
            New-Item -Path $LogDirectory -ItemType Directory > $null
        }
        $log_file = "$LogDirectory\PrinterMigration.log"
        Write-Verbose -Message $log_entry
        Add-Content -Path $log_file -Value $log_entry
    }
    # Get Default Printer
    $defaultPrinter = Get-WmiObject win32_printer | Where-Object { $_.Default -eq $true }
    if ($defaultPrinter.name -like "*\\*") {
        $defaultPrinterName = ($defaultPrinter.name).Split('\')[3]
    }
    else {
        $defaultPrinterName = $defaultPrinter.name
    }
    Write-Log -Message "Default Printer is $defaultPrinterName" -level 'Printer'
    # Get list of Current Printers
    $Printers = ((get-wmiobject win32_printer) | Where-Object { ($_.name -like "*$oldPrintServer*") })
    Write-Log -Message "List of Current Printers on old Print Server:" -level 'Printer'
    ForEach ($Printer in $Printers) {
        $currentPrinterName = ($Printer.name)
        if ($Printer.name -like "*\\*") {
            $currentPrinterName = ($Printer.name).Split('\')[3]
        }
        else {
            $currentPrinterName = $Printer.name
        }
        Write-Log -Message $currentPrinterName -level 'Printer'
    }
    if ($Printers) {
        # Change the Printer from old server to new server.
        ForEach ($Printer in $Printers) {
            $newPrinter = $printer.Name -replace $oldPrintServer, $newPrintServer
            $currentNewPrinter = $newPrinter.Split('\')[3]
            $currentOldPrinter = ($Printer.Name).Split('\')[3]
            Write-Log -Message "Adding printer $currentNewPrinter ." -level 'Printer'
            $returnValue = ([wmiclass]"Win32_Printer").AddPrinterConnection($newPrinter).ReturnValue
            If ($returnValue -eq 0) {
                Write-Log -Message "Printer $currentNewPrinter has been added." -level 'Printer'
                Write-Log -Message "Deleting $Printer ." -level 'Printer'
                $printer.Delete()
                $Status = 'success'
            }
            Else {
                Write-Log -Message "Error adding printer $currentNewPrinter Error:$returnValue" -level 'Error'
                $Status = 'Failed'
            }
        }
        if ($Status -eq 'success') {
            write-host "Printer Migration Successfull." -ForegroundColor Green
            Write-Log -Message "Printer Migration to new printer server was successfull." -level 'Printer'
        }
        else {
            Write-host "Printer Migration Failed! Please consult $LogDirectory\$log_file ." -ForegroundColor Red
            Write-Log -Message "Printer Migration to new printer server failed." -level 'Printer'
        }
    }
    else {
        Write-Log -Message 'No old Printers found.'
    }
}

Move-Printer -oldPrintServer 'essent-rad-dc01' -newPrintServer 'print-rad-prod' -LogDirectory "$env:SystemDrive\Windows\temp\PrinterMigration"