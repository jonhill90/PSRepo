Function Remove-ePoSystem {
    [CmdletBinding()]
    param
    (
        $ComputerName = (Read-Host "Enter system name."),
        $epoServer = (Read-Host "Enter ePo Server FQDN"),
        $epouser = (Read-Host "Enter username for $epoServer"),
        $epopass = (Read-Host "Enter password for $epoServer" -AsSecureString)
    )
    $epopass = $epopass | ConvertTo-SecureString -AsPlainText -Force
    $Credentials = (New-Object System.Management.Automation.PSCredential($epouser, $epopass ))
    [System.Net.ServicePointManager]::ServerCertificateValidationCallback = { $true }
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $wc = New-Object System.Net.WebClient
    $wc.DownloadString("$epoServer") | Out-Null
    $script:epoServer = $epoServer
    $script:Credentials = $Credentials
    
    $ComputerName | ForEach-Object {
        $uri = "$($epoServer)/remote/system.delete?names=$_"
        Invoke-RestMethod -Uri $uri -Credential $Credentials
    }
    
}