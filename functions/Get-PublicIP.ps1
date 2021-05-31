function Get-PublicIP {
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
		return $resp.ip
	}
}

New-Alias -Name gpip -Value Get-PublicIP
New-Alias -Name Get-PublicIPAddress -Value Get-PublicIP
