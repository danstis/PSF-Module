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
	param ()

	$ErrorActionPreference = 'Stop'

	# Check for supported applications.
	$Chocolatey = ($null -ne (Get-Command choco -ErrorAction SilentlyContinue))
	$WinGet = ($null -ne (Get-Command winget -ErrorAction SilentlyContinue))
	#Define the output file paths
	$PathChoco = "$env:temp\choco-outdated.json"
	$PathPS = "$env:temp\powershell-outdated.json"
	$PathWinGet = "$env:temp\winget-outdated.json"

	# Check PowerShell module updates.
	Write-Host 'Checking PowerShell module updates...'
	if (Test-Path $PathPS -PathType Leaf) {
		# Remove the PS update file if it exists.
		Remove-Item -Path $PathPS -Force | Out-Null
	}
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
	if ($ModuleUpdates) {
		$ModuleUpdates | ConvertTo-Json | Out-File -FilePath $PathPS -Encoding utf8 -Force
	}

	# If Chocolatey is installed, check its updates.
	if ($Chocolatey) {
		Write-Host 'Checking Chocolatey package updates...'
		if (Test-Path $PathChoco -PathType Leaf) {
			# Remove the Choco update file if it exists.
			Remove-Item -Path $PathChoco -Force | Out-Null
		}
		$ChocoOutput = & Choco outdated -r
		$ChocoUpdates = @(
			foreach ($line in $ChocoOutput) {
				if ($line -match '(.*)\|(.*)\|(.*)\|(.*)') {
					[PSCustomObject]@{
						Package          = $Matches[1]
						CurrentVersion   = $Matches[2]
						AvailableVersion = $Matches[3]
					}
				}
			}
		)
		if ($ChocoUpdates) {
			$ChocoUpdates | ConvertTo-Json | Out-File -FilePath $PathChoco -Encoding utf8 -Force
		}
	}

	# If WinGet is installed, check its updates.
	if ($WinGet) {
		Write-Host 'Checking WinGet package updates...'
		if (Test-Path $PathWinGet -PathType Leaf) {
			# Remove the WinGet update file if it exists.
			Remove-Item -Path $PathWinGet -Force | Out-Null
		}
		$WinGetOutput = & winget upgrade
		$WinGetUpdates = @(
			foreach ($line in ($WinGetOutput | Select-Object -Skip 1)) {
				if ($line -match '^(.*?) +([\w\d\.\+-_]+) +(?:< |)([\d\.\+-_]*?|Unknown) +([\d\.-]*|Unknown) +winget$') {
					[PSCustomObject]@{
						PackageId        = $Matches[2]
						CurrentVersion   = $Matches[3]
						AvailableVersion = $Matches[4]
					}
				}
			}
		)
		$WinGetUpdates = $WinGetUpdates | Where-Object { $_.CurrentVersion -ne 'Unknown' } | Sort-Object PackageId
		if ($WinGetUpdates) {
			$WinGetUpdates | ConvertTo-Json | Out-File -FilePath $PathWinGet -Encoding utf8 -Force
		}
	}

	# If Chocolatey is installed, list the available updates.
	if ($Chocolatey) {
		if (Test-Path $PathChoco -PathType Leaf) {
			$Output = Get-Content $PathChoco | ConvertFrom-Json
			if ($Output) {
				Write-Host ('{0} Chocolatey package updates are available!' -f ($Output | Measure-Object).Count) -ForegroundColor Green
				Write-Host ($Output | Format-Table | Out-String) -ForegroundColor Green
			}
		} else {
			Write-Host 'Chocolatey packages are up to date' -ForegroundColor Green
		}
	}

	# List the PS module available updates.
	if (Test-Path $PathPS -PathType Leaf) {
		$Output = Get-Content $PathPS | ConvertFrom-Json
		if ($Output) {
			Write-Host ('{0} PowerShell module updates are available!' -f ($Output | Measure-Object).Count) -ForegroundColor Green
			Write-Host ($Output | Format-Table | Out-String) -ForegroundColor Green
		}
	} else {
		Write-Host 'PowerShell modules are up to date' -ForegroundColor Green
	}

	# If Winget is installed, list the available updates.
	if ($WinGet) {
		if (Test-Path $PathWinGet -PathType Leaf) {
			$Output = Get-Content $PathWinGet | ConvertFrom-Json
			if ($Output) {
				Write-Host ('{0} Winget package updates are available!' -f ($Output | Measure-Object).Count) -ForegroundColor Green
				Write-Host ($Output | Format-Table | Out-String) -ForegroundColor Green
			}
		} else {
			Write-Host 'Winget packages are up to date' -ForegroundColor Green
		}
	}
}
