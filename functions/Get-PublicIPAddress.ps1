function Get-PublicIPAddress {
	<#
	.SYNOPSIS
	   Returns the local machines Public IP address.
	.DESCRIPTION
	   Returns the local machines Public IP address.
	.EXAMPLE
	   Get-PublicIPAddress
	.NOTES
		Version 1.0.0
	#>

	return (Resolve-DnsName -Name myip.opendns.com -Server resolver1.opendns.com).IPAddress
}
