function Get-Updates {
	<#
	.SYNOPSIS
		Checks for software/module updates
	.DESCRIPTION
		Supports checking Chocolatey/WinGet/PowerShell module updates.
	.EXAMPLE
		C:\PS> .\Get-Updates.ps1
		Checks updates for all known installed package managers.
	.OUTPUTS
		Creates outdated package files in the temp directory ($env:Temp).
		Displays the outdated packages on the console.
	.NOTES
		Version 1.0.0
	#>
	[CmdletBinding()]
	param (	)

	begin {
		$ErrorActionPreference = 'Stop'
		# Check for supported applications.
		$Chocolatey = $null -ne (Get-Command choco -ErrorAction SilentlyContinue)
		$WinGet = $null -ne (Get-Command winget -ErrorAction SilentlyContinue)
	}

	process {
		# Check PowerShell module updates.
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

		# If Chocolatey is installed, check its updates.
		if ($Chocolatey) {
			& Choco outdated -r | Out-File -FilePath "$env:temp\choco-outdated.txt" -Encoding utf8 -Force
		}
		# If WinGet is installed, check its updates.
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
			} else {
				Write-Host 'Chocolatey packages are up to date!' -ForegroundColor Green
			}
		}

		if (Test-Path "$env:TEMP\powershell-outdated.json" -ea 'SilentlyContinue') {
			$Output = Get-Content "$env:TEMP\powershell-outdated.json" | ConvertFrom-Json
			if ($Output) {
				Write-Host ('{0} PowerShell module updates are available!' -f ($Output | Measure-Object).Count) -ForegroundColor Green
				Write-Host ($Output | Format-Table | Out-String) -ForegroundColor Green
			}
		} else {
			Write-Host 'PowerShell modules are up to date!' -ForegroundColor Green
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
			} else {
				Write-Host 'Winget packages are up to date!' -ForegroundColor Green
			}
		}
	}
}
