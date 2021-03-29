function Get-WiFiKnownPasswords {
	<#
	.SYNOPSIS
	   List all known WiFi Passwords
	.DESCRIPTION
	   Retrieves the known WiFi passwords using netsh and displays them in a table.
	.EXAMPLE
	   Get-WiFiKnownPasswords
	.NOTES
		Version 1.0.0
	#>
	[Cmdletbinding()]
	Param()

	$WLANList = (netsh.exe wlan show profiles) -match ': '
	$WifiNetworks = @()
	$Output = @()
	foreach ($WLAN in $WLANList) { $WifiNetworks += ($WLAN -split ": ")[-1] }
	foreach ($WifiNetwork in $WifiNetworks) {
		$WifiDetails = netsh wlan show profile $WifiNetwork key=clear
		$Output += [PSCustomObject]@{
			Name     = (($WifiDetails -match "(?-i)Name") -split ": ")[-1]
			Password = (($WifiDetails -match "Key Content") -split ": ")[-1]
		}
	}
	return $Output | Sort-Object Name
}
