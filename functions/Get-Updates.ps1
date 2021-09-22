function Get-Updates {
	<#
	.SYNOPSIS
		Checks for software/module updates
	.DESCRIPTION
		Supports checking Chocolatey/WinGet/PowerShell module updates.
	.EXAMPLE
		C:\PS> .\Get-Updates.ps1
		Checks updates for all package managers.
	.PARAMETER Chocolatey
		Switch parameter controlling the checking of Chocolatey outdated packages.
	.PARAMETER PowerShell
		Switch parameter controlling the checking of PowerShell module updates.
	.PARAMETER WinGet
		Switch parameter controlling the checking of WinGet outdated packages.
	.PARAMETER All
		Will run the update check for all package managers.
	.OUTPUTS
		Creates outdated package files in the temp directory ($env:Temp).
		Displays the outdated packages on the console.
	.NOTES
		Version 1.0.0
	#>
	[CmdletBinding()]
	param (
		# Check for Chocolatey updates
		[Parameter(mandatory = $false, ParameterSetName = 'Individual')]
		[switch] $Chocolatey,
		# Check for PowerShell module updates
		[Parameter(mandatory = $false, ParameterSetName = 'Individual')]
		[switch] $PowerShell,
		# Check for WinGet updates
		[Parameter(mandatory = $false, ParameterSetName = 'Individual')]
		[switch] $WinGet,
		# All is the same as providing all the switches above
		[Parameter(mandatory = $false, ParameterSetName = 'Group')]
		[switch] $All
	)

	begin {
		$ErrorActionPreference = 'Stop'
		if ($All) {
			$Chocolatey = $PowerShell = $WinGet = $true
		}
		if (!$Chocolatey -and !$PowerShell -and !$WinGet -and !$All) {
			# If no params are set, then only check PowerShell modules
			$PowerShell = !$PowerShell
		}
	}

	process {
		if ($Chocolatey) {
			& Choco outdated -r | Out-File -FilePath "$env:temp\choco-outdated.txt" -Encoding utf8 -Force
		}
		if ($PowerShell) {
			$Modules = Get-Module -ListAvailable | Where-Object { `
					$_.RepositorySourceLocation -and `
					$_.Name -notlike 'Az.*' -and `
					$_.Name -notlike 'AzureRM.*' -and `
					$_.Name -notlike 'Microsoft.Graph.*' `
			} | Group-Object Name | Select-Object Name, @{n = 'Version'; e = { $_.Group[0].Version } }
			$ModuleUpdates = foreach ($Module in $Modules) {
				try {
					$Available = Find-Module $Module.Name
					if ([version]($Available).Version -gt [version]$Module.Version) {
						[PSCustomObject]@{
							Module           = $Module.Name
							CurrentVersion   = $Module.Version.ToString()
							AvailableVersion = $Available.Version
						}
					}
				} catch {
					Write-Warning ('Failed to find details for module "{0}": {1}' -f $Module.Name, $_.Exception.Message)
				}
			}
			$ModuleUpdates | ConvertTo-Json | Out-File -FilePath "$env:temp\powershell-outdated.json" -Encoding utf8 -Force
		}
		if ($WinGet) {
			& winget upgrade | Out-File -FilePath "$env:temp\winget-outdated.txt" -Encoding utf8 -Force
		}
	}

	end {
		if ($Chocolatey -and (Test-Path "$env:TEMP\choco-outdated.txt" -ea 'SilentlyContinue')) {
			$Detail = Get-Content "$env:TEMP\choco-outdated.txt"
			$Output = @(
				foreach ($line in $Detail) {
					if ($line -match '(.*)\|(.*)\|(.*)\|(.*)') {
						[PSCustomObject]@{
							Package          = $Matches[1]
							CurrentVersion   = $Matches[2]
							AvailableVersion = $Matches[3]
						}
					}
				}
			)
			if ($Output) {
				Write-Host ('{0} Chocolatey package updates are available!' -f ($Output | Measure-Object).Count) -ForegroundColor Green
				Write-Host ($Output | Format-Table | Out-String) -ForegroundColor Green
			}
		}

		if ($PowerShell -and (Test-Path "$env:TEMP\powershell-outdated.json" -ea 'SilentlyContinue')) {
			$Output = Get-Content "$env:TEMP\powershell-outdated.json" | ConvertFrom-Json
			if ($Output) {
				Write-Host ('{0} PowerShell module updates are available!' -f ($Output | Measure-Object).Count) -ForegroundColor Green
				Write-Host ($Output | Format-Table | Out-String) -ForegroundColor Green
			}
		}

		if ($WinGet -and (Test-Path "$env:TEMP\winget-outdated.txt" -ea 'SilentlyContinue')) {
			$Detail = Get-Content "$env:TEMP\winget-outdated.txt"
			$Output = @(
				foreach ($line in ($Detail | Select-Object -Skip 1)) {
					if ($line -match '^(.*?) +([\w\d\.\+-_]+) +([\d\.\+-_]*?|Unknown) +([\d\.-]*|Unknown) +winget$') {
						[PSCustomObject]@{
							PackageId        = $Matches[2]
							CurrentVersion   = $Matches[3]
							AvailableVersion = $Matches[4]
						}
					}
				}
			)
			$Output = $Output | Where-Object { $_.CurrentVersion -ne 'Unknown' } | Sort-Object PackageId
			if ($Output) {
				Write-Host ('{0} Winget package updates are available!' -f ($Output | Measure-Object).Count) -ForegroundColor Green
				Write-Host ($Output | Format-Table | Out-String) -ForegroundColor Green
			}
		}
	}
}
