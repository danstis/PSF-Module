function Get-PublicIP {
	<#
	.SYNOPSIS
		Returns the public IP address for the connected network.
	.DESCRIPTION
		Uses the ipify.org API to lookup the Public IP address.
		The function will return the Public IP as well as copy it to your clipboard.
	.EXAMPLE
		C:\PS> Get-PublicIP
		Returns the current IPv4 Public IP for the connected network.
	.EXAMPLE
		C:\PS> Get-PublicIP -v6
		Returns the current IPv6 (if available) Public IP for the connected network.
	.OUTPUTS
		Public IP address(es)
	.NOTES
		Version 1.0.0
	#>
	[CmdletBinding()]
	param (
		# IPv6 switch
		[Parameter(Mandatory = $false, HelpMessage = 'Perform an IPv6 lookup')]
		[switch] $v6
	)

	begin {
		$ErrorActionPreference = 'Stop'
		$Uri = 'https://api.ipify.org?format=json'
		if ($6) {
			$Uri = 'https://api64.ipify.org?format=json'
		}
	}

	process {
		$resp = (Invoke-WebRequest $Uri -ErrorAction 'stop').Content | ConvertFrom-Json
	}

	end {
		$resp.ip | clip
		return $resp.ip
	}
}

New-Alias -Name gpip -Value Get-PublicIP
New-Alias -Name Get-PublicIPAddress -Value Get-PublicIP
