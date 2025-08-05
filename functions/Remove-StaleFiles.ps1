function Remove-StaleFiles {
	<#
	.SYNOPSIS
		Remove stale files and directories recursively based on modification time.
	.DESCRIPTION
		Remove-StaleFiles recursively removes files and directories that have not been modified within a specified number of days.
		Files and directories older than the specified age are considered "stale" and will be removed.
		Logs are written to daily files in the user's temp directory with automatic cleanup.

		Safety checks prevent execution on system directories (Windows: drive roots, Program Files, Windows directory; Unix/Linux: /, /etc, /bin, etc.).
		Use -AllowSystemPaths to bypass these protections with extreme caution.
	.PARAMETER Path
		The directory path to process. Defaults to the current user's temporary directory.
	.PARAMETER Age
		The number of days before a file or directory is considered stale. Files/directories not modified within this period will be removed.
	.PARAMETER Extension
		Optional file extension filter. Only files with this extension will be considered for removal.
	.PARAMETER Force
		Skip confirmation prompts and remove files without asking.
	.PARAMETER LogRetentionDays
		Number of days to keep daily log files. Defaults to 7 days.
	.PARAMETER AllowSystemPaths
		Allow processing of system directories. Use with extreme caution as this can damage your system.
	.EXAMPLE
		C:\PS> Remove-StaleFiles -Age 30 -Path "C:\Temp"
		Removes all files and directories in C:\Temp that haven't been modified in 30 days.
	.EXAMPLE
		C:\PS> Remove-StaleFiles -Age 7 -Extension ".log" -WhatIf
		Shows what .log files would be removed that are older than 7 days, without actually deleting them.
	.EXAMPLE
		C:\PS> Remove-StaleFiles -Age 14 -Force
		Removes all files in the temp directory older than 14 days without confirmation.
	.EXAMPLE
		C:\PS> Remove-StaleFiles -Age 30 -LogRetentionDays 14
		Removes stale files and keeps log files for 14 days instead of the default 7.
	.OUTPUTS
		Summary of removed files and directories.
	.NOTES
		Version 1.1.0
	#>
	[CmdletBinding(SupportsShouldProcess)]
	param(
		[Parameter(Mandatory = $false, HelpMessage = 'Directory path to process')]
		[string] $Path = [System.IO.Path]::GetTempPath(),
		[Parameter(Mandatory = $true, HelpMessage = 'Number of days before a file is considered stale')]
		[int] $Age,
		[Parameter(Mandatory = $false, HelpMessage = 'File extension filter')]
		[string] $Extension,
		[Parameter(Mandatory = $false)]
		[switch] $Force,
		[Parameter(Mandatory = $false, HelpMessage = 'Number of days to keep log files')]
		[int] $LogRetentionDays = 7,
		[Parameter(Mandatory = $false, HelpMessage = 'Allow processing of system directories (use with extreme caution)')]
		[switch] $AllowSystemPaths
	)
	$ErrorActionPreference = 'Stop'
	$InformationPreference = 'Continue'
	$StartTime = Get-Date

	# Set up logging - use appropriate temp directory for the platform.
	$TempDir = [System.IO.Path]::GetTempPath()
	$LogDir = Join-Path $TempDir 'PSF-Module/Logs'
	$LogName = 'RemoveStaleFiles'
	$DateSuffix = Get-Date -Format 'yyyy-MM-dd'
	$LogPath = Join-Path $LogDir ('{0}-{1}.log' -f $LogName, $DateSuffix)

	function Write-StaleFileLog {
		param(
			[string] $Message,
			[string] $Level = 'INFO'
		)

		if (-not (Test-Path $LogDir)) {
			$null = New-Item -Path $LogDir -ItemType Directory -Force
		}

		$Timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
		$LogEntry = '{0} [{1}] {2}' -f $Timestamp, $Level, $Message
		$LogEntry | Out-File -FilePath $LogPath -Append -Encoding UTF8
	}

	function Test-SystemPath {
		param(
			[string] $TestPath
		)

		# Resolve to absolute path.
		$FullPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($TestPath)

		# Get blocked paths using system variables where available.
		$BlockedPaths = @()

		# Windows system paths
		if ($IsWindows -or $env:OS -eq 'Windows_NT') {
			# Drive roots (C:\, D:\, etc.).
			$BlockedPaths += Get-PSDrive -PSProvider FileSystem | ForEach-Object { $_.Root }

			# System directories using environment variables.
			if ($env:SystemRoot) { $BlockedPaths += $env:SystemRoot }
			if ($env:ProgramFiles) { $BlockedPaths += $env:ProgramFiles }
			if ($env:ProgramData) { $BlockedPaths += $env:ProgramData }
			if ($env:ProgramW6432) { $BlockedPaths += $env:ProgramW6432 }
			if (${env:ProgramFiles(x86)}) { $BlockedPaths += ${env:ProgramFiles(x86)} }

			# .NET system directory.
			try {
				$BlockedPaths += [Environment]::SystemDirectory
			} catch { }
		}

		# Unix/Linux system paths.
		if ($IsLinux -or $IsMacOS -or (!$IsWindows -and $env:OS -ne 'Windows_NT')) {
			$BlockedPaths += @(
				'/',
				'/etc',
				'/bin',
				'/sbin',
				'/usr',
				'/boot',
				'/sys',
				'/proc'
			)
		}

		# macOS additional paths.
		if ($IsMacOS) {
			$BlockedPaths += @(
				'/System',
				'/Applications'
			)
		}

		# Check if the test path matches or is a parent of any blocked path.
		foreach ($BlockedPath in $BlockedPaths) {
			if (-not $BlockedPath) { continue }

			try {
				$ResolvedBlockedPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($BlockedPath)

				# Normalize paths for comparison (handle trailing separators).
				$NormalizedTestPath = $FullPath.TrimEnd([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar)
				$NormalizedBlockedPath = $ResolvedBlockedPath.TrimEnd([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar)

				# Check for exact match.
				if ($NormalizedTestPath -eq $NormalizedBlockedPath) {
					return $true
				}
			}
			catch {
				# If path resolution fails, skip this check.
				continue
			}
		}

		return $false
	}

	function Clear-OldLogs {
		param(
			[string] $LogDirectory,
			[string] $LogPrefix,
			[int] $RetentionDays
		)

		if (Test-Path $LogDirectory) {
			$CutoffDate = (Get-Date).AddDays(-$RetentionDays)
			Get-ChildItem -Path $LogDirectory -Filter ('{0}-*.log' -f $LogPrefix) |
				Where-Object { $_.LastWriteTime -lt $CutoffDate } |
				ForEach-Object {
					try {
						Remove-Item -Path $_.FullName -Force
						Write-Verbose ('Cleaned up old log file: {0}' -f $_.Name)
					}
					catch {
						Write-Warning ('Failed to remove old log file {0}: {1}' -f $_.Name, $_.Exception.Message)
					}
				}
		}
	}

	# Clean up old logs.
	Clear-OldLogs -LogDirectory $LogDir -LogPrefix $LogName -RetentionDays $LogRetentionDays

	# Log function start.
	$LogParams = @(
		('Path: {0}' -f $Path)
		('Age: {0} days' -f $Age)
	)
	if ($Extension) { $LogParams += ('Extension: {0}' -f $Extension) }
	if ($Force) { $LogParams += 'Force: True' }
	if ($WhatIfPreference) { $LogParams += 'WhatIf: True' }

	Write-StaleFileLog ('STARTED Remove-StaleFiles - {0}' -f ($LogParams -join ', '))

	if (-not (Test-Path -Path $Path)) {
		$ErrorMsg = ('Path ''{0}'' does not exist.' -f $Path)
		Write-StaleFileLog $ErrorMsg 'ERROR'
		Write-Error $ErrorMsg
		return
	}

	# Safety check: prevent running on system directories unless explicitly allowed
	if (-not $AllowSystemPaths -and (Test-SystemPath -TestPath $Path)) {
		$ErrorMsg = ('Path ''{0}'' is a system directory. Use -AllowSystemPaths to override this safety check.' -f $Path)
		Write-StaleFileLog $ErrorMsg 'ERROR'
		Write-Error $ErrorMsg
		return
	}

	$CutoffDate = (Get-Date).AddDays(-$Age)

	Write-Verbose ('Scanning for files older than {0} days (before {1})' -f $Age, $CutoffDate.ToString('yyyy-MM-dd HH:mm:ss'))
	Write-Verbose ('Processing path: {0}' -f $Path)

	# Get all items recursively and filter by age and extension.
	try {
		$AllItems = Get-ChildItem -Path $Path -Recurse -Force
	}
	catch {
		$ErrorMsg = ('Unable to access directory: {0} - {1}' -f $Path, $_.Exception.Message)
		Write-StaleFileLog $ErrorMsg 'ERROR'
		Write-Warning $ErrorMsg
		return
	}

	$ItemsToRemove = @()

	# Process files first.
	$StaleFiles = $AllItems | Where-Object {
		-not $_.PSIsContainer -and
		$_.LastWriteTime -lt $CutoffDate -and
		(-not $Extension -or $_.Extension -eq $Extension)
	}
	$ItemsToRemove += $StaleFiles

	# Process directories (empty ones that are stale).
	$StaleDirectories = $AllItems | Where-Object {
		$_.PSIsContainer -and
		$_.LastWriteTime -lt $CutoffDate
	} | Where-Object {
		try {
			$ChildItems = Get-ChildItem -Path $_.FullName -Force
			$ChildItems.Count -eq 0
		}
		catch {
			Write-Warning ('Unable to check contents of directory: {0} - {1}' -f $_.FullName, $_.Exception.Message)
			$false
		}
	}
	$ItemsToRemove += $StaleDirectories

	if ($ItemsToRemove.Count -eq 0) {
		Write-StaleFileLog 'No stale files found'
		Write-Information 'No stale files found.'
		return
	}

	$Files = $ItemsToRemove | Where-Object { -not $_.PSIsContainer }
	$Directories = $ItemsToRemove | Where-Object { $_.PSIsContainer }

	Write-Information ('Found {0} stale items:' -f $ItemsToRemove.Count)
	Write-StaleFileLog ('Found {0} stale items: {1} files, {2} directories' -f $ItemsToRemove.Count, $Files.Count, $Directories.Count)

	if ($Files.Count -gt 0) {
		Write-Information ('  Files: {0}' -f $Files.Count)
		if ($VerbosePreference -eq 'Continue') {
			$Files | ForEach-Object { Write-Verbose ('    {0} ({1})' -f $_.FullName, (Get-Date $_.LastWriteTime -Format 'yyyy-MM-dd HH:mm:ss')) }
		}
	}

	if ($Directories.Count -gt 0) {
		Write-Information ('  Directories: {0}' -f $Directories.Count)
		if ($VerbosePreference -eq 'Continue') {
			$Directories | ForEach-Object { Write-Verbose ('    {0} ({1})' -f $_.FullName, (Get-Date $_.LastWriteTime -Format 'yyyy-MM-dd HH:mm:ss')) }
		}
	}

	if ($WhatIfPreference) {
		Write-StaleFileLog ('WhatIf mode: Would remove {0} stale items' -f $ItemsToRemove.Count)
		Write-Information ('WhatIf: Would remove {0} stale items.' -f $ItemsToRemove.Count)
		return
	}

	if (-not $Force) {
		$Response = Read-Host ('Do you want to remove these {0} items? (y/N)' -f $ItemsToRemove.Count)
		if ($Response -ne 'y' -and $Response -ne 'Y') {
			Write-StaleFileLog 'Operation cancelled by user'
			Write-Information 'Operation cancelled.'
			return
		}
	}

	$RemovedCount = 0
	$FailedCount = 0

	foreach ($Item in $ItemsToRemove) {
		if ($PSCmdlet.ShouldProcess($Item.FullName, 'Remove')) {
			try {
				$ItemType = if ($Item.PSIsContainer) { 'Directory' } else { 'File' }
				$ItemSize = if (-not $Item.PSIsContainer) { $Item.Length } else { 0 }

				if ($Item.PSIsContainer) {
					Remove-Item -Path $Item.FullName -Force -Recurse
				}
				else {
					Remove-Item -Path $Item.FullName -Force
				}
				$RemovedCount++

				Write-Verbose ('Removed: {0}' -f $Item.FullName)
				Write-StaleFileLog ('REMOVED {0}: {1} (Last Modified: {2}, Size: {3} bytes)' -f $ItemType, $Item.FullName, $Item.LastWriteTime.ToString('yyyy-MM-dd HH:mm:ss'), $ItemSize)
			}
			catch {
				$FailedCount++
				$ErrorMsg = ('Failed to remove ''{0}'': {1}' -f $Item.FullName, $_.Exception.Message)
				Write-Warning $ErrorMsg
				Write-StaleFileLog $ErrorMsg 'ERROR'
			}
		}
	}

	# Log completion summary.
	$Duration = (Get-Date) - $StartTime
	$SummaryMsg = ('COMPLETED: Successfully removed {0} items, {1} failures in {2:F2} seconds' -f $RemovedCount, $FailedCount, $Duration.TotalSeconds)
	Write-StaleFileLog $SummaryMsg

	Write-Information 'Removal complete:'
	Write-Information ('  Successfully removed: {0} items' -f $RemovedCount)
	if ($FailedCount -gt 0) {
		Write-Information ('  Failed to remove: {0} items' -f $FailedCount)
	}
}
