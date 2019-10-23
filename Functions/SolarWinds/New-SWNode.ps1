function New-SWNode {
    [CmdletBinding(
        SupportsShouldProcess = $True
    )]
    [OutputType([int])]
    Param
    (
        #The IP address of the node to be added for monitoring
        $NodeName,
        $Company,
        $Team,
        $Environment,
        $Vendor,
        # SolarWinds Server
        $swServer,
        [int32]$engineid = 1,
        [int32]$status = 1,
        #Whether the device is Unmanaged or not (default = false)
        $UnManaged = $false,
        $DynamicIP = $false,
        $Allow64BitCounters = $true,
        $Community
    )
    Begin {
        #Nested Function
        $ComputerName = $NodeName
        Function Get-SWNode {
            [CmdletBinding()]
            param
            (
                $ComputerName,
                $swServer,
                $CustomProperties = "False"
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
                Write-host "$ComputerName not found." -ForegroundColor Red
            }
        }
        Write-Host "Starting $($myinvocation.mycommand)"
        $SwisConnection = Connect-Swis -Hostname $swServer -Trusted
        $swis = Connect-Swis -Hostname $swServer -Trusted
        $IPAddress = (Resolve-DnsName -Name $NodeName).IPAddress
        $SerialBug = $false
    
        $ipguid = [guid]::NewGuid()
    
        $newNodeProps = @{
            EntityType           = "Orion.Nodes";
            IPAddress            = $IPAddress;
            IPAddressGUID        = $ipGuid;
            Caption              = $NodeName;
            DynamicIP            = $DynamicIP;
            EngineID             = $engineid;
            Status               = $status;
            UnManaged            = $UnManaged;
            Allow64BitCounters   = $Allow64BitCounters;
            Location             = "";
            Contact              = "";
            NodeDescription      = "";
            Vendor               = "$Vendor";
            IOSImage             = "";
            IOSVersion           = "";
            SysObjectID          = "";
            MachineType          = "";
            VendorIcon           = "";
            # SNMP v2 specific
            ObjectSubType        = "SNMP";
            SNMPVersion          = 2;
            Community            = $Community;
            BufferNoMemThisHour  = "-2"; 
            BufferNoMemToday     = "-2"; 
            BufferSmMissThisHour = "-2"; 
            BufferSmMissToday    = "-2"; 
            BufferMdMissThisHour = "-2"; 
            BufferMdMissToday    = "-2"; 
            BufferBgMissThisHour = "-2"; 
            BufferBgMissToday    = "-2"; 
            BufferLgMissThisHour = "-2"; 
            BufferLgMissToday    = "-2"; 
            BufferHgMissThisHour = "-2"; 
            BufferHgMissToday    = "-2"; 
            PercentMemoryUsed    = "-2"; 
            TotalMemory          = "-2";                     
        }
        #next define the pollers for interfaces
        $PollerTypes = @("N.Status.ICMP.Native", "N.ResponseTime.ICMP.Native", "N.Details.SNMP.Generic", "N.Uptime.WMI.XP", "N.Cpu.WMI.Windows", "N.Memory.WMI.Windows")
        $CustomProperties = @{
            Company        = "$Company";
            Environment    = "$Environment";
            Production     = "$Team";
        }
        # Discover Storage on Node 
        Write-Host "Discovering Volumes on Node $NodeName"
        [array]$drives = Get-CimInstance Win32_Logicaldisk -ComputerName $NodeName -Filter "DriveType=3" | Select-Object Caption, VolumeName, VolumeSerialNumber, DriveLetter, DriveType;
    
        # Discover Memory on Node
        Write-Host "Discovering Virtual and Physical Memory on Node $NodeName"
        $MemoryList = @("Virtual Memory", "Physical Memory")  
    }
    Process {
        Write-Host "Adding $NodeName to Orion Database"
        If ($PSCmdlet.ShouldProcess("$IPAddress", "Add Node")) {
            $newNode = New-SwisObject $SwisConnection -EntityType "Orion.Nodes" -Properties $newNodeProps
            $nodeProps = Get-SwisObject $SwisConnection -Uri $newNode
            $newNodeUri = (Get-SWNode -ComputerName $NodeName -swServer $swServer -CustomProperties True).uri
            Set-SwisObject $SwisConnection -Uri $newNodeUri -Properties $CustomProperties
        }
            
        Write-Host "Node added with URI = $newNode"
        $NodeID = (get-orionNodeID -SwisConnection $swis -NodeName $NodeName)
        Write-Host "$NodeID"
    
        Write-Host "Now Adding pollers for the node..." 
        $nodeProps = Get-SwisObject $SwisConnection -Uri $newNode
        #Loop through all the pollers 
        foreach ($PollerType in $PollerTypes) {
            If ($PSCmdlet.ShouldProcess("$PollerTypes", "Add Poller")) {
                New-OrionPollerType -PollerType $PollerType -NodeProperties $nodeProps -SwisConnection $SwisConnection
            }          
        }
        foreach ($drive in $drives) {
            $VolumeExists = $Null
            $VolumeDescription = ''
            $VolumeCaption = ''
            if ($drive.DriveType -eq 3) {
                $VolumeIndex = $drives.IndexOf($drive) + 1
                $driveSerial = $drive.VolumeSerialNumber.ToLower()
                Switch ($SerialBug) {
                    True {
                        $driveSerialBug = $driveSerial -replace "^0", ""
                        $VolumeDescriptionBug = "$($drive.Caption)\ Label:$($drive.VolumeName)  Serial Number $($driveSerialBug)"
                        $VolumeCaptionBug = "$($drive.Caption)\ Label:$($drive.VolumeName) $($driveSerialBug)";
                        $VolumeDescription = $VolumeDescriptionBug
                        $VolumeCaption = $VolumeSerialBug
                        Write-Debug $VolumeDescription
                        Write-Debug $VolumeCaption
                    }
                    False {
                        $VolumeDescription = "$($drive.Caption)\ Label:$($drive.VolumeName)  Serial Number $($driveSerial)"
                        $VolumeCaption = "$($drive.Caption)\ Label:$($drive.VolumeName) $($driveSerial)";
                        Write-Debug $VolumeDescription
                        Write-Debug $VolumeCaption
                    }
                }
            }
            else {
                continue
            }
        }
        If ($SerialBug -eq $True) {
            $VolumeExists = Get-SwisData $swis "SELECT NodeID FROM Orion.Volumes WHERE NodeID=$NodeID AND VolumeDescription = $VolumeDescription"
        }
        If ($VolumeExists -eq $null) {
            $newVolProps = @{
                NodeID              = "$NodeID";
                VolumeIndex         = [int]$VolumeIndex;
                VolumeTypeID        = 4;
                VolumeSize          = "0";
                Type                = "Fixed Disk";
                Icon                = "FixedDisk.gif";
                Caption             = $VolumeCaption;
                VolumeDescription   = $VolumeDescription;
                PollInterval        = 120;
                StatCollection      = 15;
                RediscoveryInterval = 30;
                FullName            = $("$NodeName-$VolumeCaption")
            }
                                
            $newVolUri = New-SwisObject $swis -EntityType "Orion.Volumes" -Properties $newVolProps
            $VolProps = Get-SwisObject $swis -Uri $newVolUri
            Write-Debug $VolProps
            Write-Debug $newVolUri
            foreach ($pollerType in @('V.Status.SNMP.Generic', 'V.Details.SNMP.Generic', 'V.Statistics.SNMP.Generic')) {
                $poller = @{
                    PollerType    = $pollerType;
                    NetObject     = "V:" + $VolProps["VolumeID"];
                    NetObjectType = "V";
                    NetObjectID   = $VolProps["VolumeID"];
                }
                $pollerUri = New-SwisObject $swis -EntityType "Orion.Pollers" -Properties $poller
            }
            Start-Sleep 1
        }
        
        foreach ($Memory in $Memorylist) {
            $VolumeExists = $Null
            $VolumeDescription = "$Memory";
            Write-Debug "$VolumeDescription"
            $VolumeCaption = "$Memory";
            Write-Debug "$VolumeCaption"
            If ($Memory -like "Virtual memory") {
                $Type = "Virtual Memory" 
                $TypeID = 3
                                
            }
            If ($Memory -like "Physical memory") {
                $Type = "RAM"
                $TypeID = 2
            }
                            
            $TypeNoSpace = $Type.replace(" ", "")
            If ($SerialBug -eq $True) {
                $VolumeExists = Get-SwisData $swis "SELECT NodeID FROM Orion.Volumes WHERE NodeID=$NodeID AND VolumeDescription = $VolumeDescription"
            }
            If ($VolumeExists -eq $null) {
                $newVolProps = @{
                    NodeID              = "$NodeID";
                    Status              = 0;
                    VolumeIndex         = [int]$VolumeIndex;
                    VolumeTypeID        = $TypeID;
                    VolumeSize          = "0";
                    Type                = $Type;
                    Icon                = $("$TypeNoSpace.gif");
                    Caption             = $VolumeCaption;
                    VolumeDescription   = $VolumeDescription;
                    PollInterval        = 120;
                    StatCollection      = 15;
                    RediscoveryInterval = 30;
                    FullName            = $("$NodeName-$VolumeCaption")
                }
                $newVolUri = New-SwisObject $swis -EntityType "Orion.Volumes" -Properties $newVolProps
                $VolProps = Get-SwisObject $swis -Uri $newVolUri
                Write-Debug $VolProps
                Write-Debug $newVolUri
                foreach ($pollerType in @('V.Status.SNMP.Generic', 'V.Details.SNMP.Generic', 'V.Statistics.SNMP.Generic')) {
                    $poller = @{
                        PollerType    = $pollerType;
                        NetObject     = "V:" + $VolProps["VolumeID"];
                        NetObjectType = "V";
                        NetObjectID   = $VolProps["VolumeID"];
                    }
                    $pollerUri = New-SwisObject $swis -EntityType "Orion.Pollers" -Properties $poller
                }
                $VolumeIndex++
            }
        }
    
        # Trigger a PollNow on the node to cause other properties and stats to be filled in
        Invoke-SwisVerb $swis Orion.Nodes PollNow @("N:" + $NodeID)
    }
    End {
        Write-Output "$newNode"
        Write-Host "Finishing $($myinvocation.mycommand)"
    }
}