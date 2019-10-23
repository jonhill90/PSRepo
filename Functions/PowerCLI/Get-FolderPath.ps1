function Get-FolderPath {
	param(
		[parameter(valuefrompipeline = $true,
			position = 0,
			HelpMessage = "Enter a folder")]
		[VMware.VimAutomation.ViCore.Impl.V1.Inventory.FolderImpl[]]$Folder,
		[switch]$ShowHidden = $false
	)
	 
	begin {
		$excludedNames = "Datacenters", "vm", "host"
	}
	 
	process {
		$Folder | % {
			$fld = $_.Extensiondata
			$fldType = "yellow"
			if ($fld.ChildType -contains "VirtualMachine") {
				$fldType = "blue"
			}
			$path = $fld.Name
			while ($fld.Parent) {
				$fld = Get-View $fld.Parent
				if ((!$ShowHidden -and $excludedNames -notcontains $fld.Name) -or $ShowHidden) {
					$path = $fld.Name + "\" + $path
				}
			}
			$row = "" | Select Name, Path, Type, Id
			$row.Name = $_.Name
			$row.Path = $path
			$row.Type = $fldType
			$row.Id = $_.Id
			$row
		}
	}
}