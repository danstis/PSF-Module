#Requires -Modules Pester

Import-Module $PSScriptRoot\..\PSF.psm1 -Force

Describe 'Remove-StaleFiles' {

	BeforeAll {
		$TestPath = Join-Path $TestDrive 'StaleFilesTest'
		New-Item -Path $TestPath -ItemType Directory -Force | Out-Null
	}

	BeforeEach {
		Get-ChildItem -Path $TestPath -Recurse | Remove-Item -Force -Recurse -ErrorAction SilentlyContinue

		$OldFile = Join-Path $TestPath 'old.txt'
		$NewFile = Join-Path $TestPath 'new.txt'
		$OldLogFile = Join-Path $TestPath 'old.log'
		$NewLogFile = Join-Path $TestPath 'new.log'
		$OldDir = Join-Path $TestPath 'OldDirectory'
		$NewDir = Join-Path $TestPath 'NewDirectory'

		'old content' | Out-File -FilePath $OldFile
		'new content' | Out-File -FilePath $NewFile
		'old log' | Out-File -FilePath $OldLogFile
		'new log' | Out-File -FilePath $NewLogFile

		New-Item -Path $OldDir -ItemType Directory | Out-Null
		New-Item -Path $NewDir -ItemType Directory | Out-Null

		$OldDate = (Get-Date).AddDays(-15)
		$NewDate = (Get-Date).AddDays(-1)

		(Get-Item $OldFile).LastWriteTime = $OldDate
		(Get-Item $OldLogFile).LastWriteTime = $OldDate
		(Get-Item $OldDir).LastWriteTime = $OldDate
		(Get-Item $NewFile).LastWriteTime = $NewDate
		(Get-Item $NewLogFile).LastWriteTime = $NewDate
		(Get-Item $NewDir).LastWriteTime = $NewDate
	}

	Context 'Parameter Validation' {
		It 'Should require Age parameter' {
			{ Remove-StaleFiles -Path $TestPath } | Should -Throw
		}

		It 'Should handle non-existent path' {
			{ Remove-StaleFiles -Path 'C:\NonExistentPath' -Age 10 -ErrorAction Stop } | Should -Throw
		}

		It 'Should use temp directory as default path' {
			# Test that the function accepts no path parameter and uses default
			{ Remove-StaleFiles -Age 10 -WhatIf } | Should -Not -Throw
		}
	}

	Context 'File Detection' {
		It 'Should identify stale files based on age' {
			$Result = Remove-StaleFiles -Path $TestPath -Age 10 -WhatIf -Verbose

			Test-Path (Join-Path $TestPath 'old.txt') | Should -Be $true
			Test-Path (Join-Path $TestPath 'new.txt') | Should -Be $true
		}

		It 'Should filter by extension when specified' {
			Remove-StaleFiles -Path $TestPath -Age 10 -Extension '.log' -Force

			Test-Path (Join-Path $TestPath 'old.txt') | Should -Be $true
			Test-Path (Join-Path $TestPath 'old.log') | Should -Be $false
			Test-Path (Join-Path $TestPath 'new.log') | Should -Be $true
		}

		It 'Should handle empty directories' {
			$EmptyOldDir = Join-Path $TestPath 'EmptyOldDir'
			New-Item -Path $EmptyOldDir -ItemType Directory | Out-Null
			(Get-Item $EmptyOldDir).LastWriteTime = (Get-Date).AddDays(-15)

			Remove-StaleFiles -Path $TestPath -Age 10 -Force

			Test-Path $EmptyOldDir | Should -Be $false
		}
	}

	Context 'WhatIf Functionality' {
		It 'Should not remove files when WhatIf is specified' {
			Remove-StaleFiles -Path $TestPath -Age 10 -WhatIf

			Test-Path (Join-Path $TestPath 'old.txt') | Should -Be $true
			Test-Path (Join-Path $TestPath 'old.log') | Should -Be $true
		}
	}

	Context 'Force Parameter' {
		It 'Should remove files without confirmation when Force is used' {
			Remove-StaleFiles -Path $TestPath -Age 10 -Force

			Test-Path (Join-Path $TestPath 'old.txt') | Should -Be $false
			Test-Path (Join-Path $TestPath 'new.txt') | Should -Be $true
		}
	}

	Context 'Error Handling' {
		It 'Should handle access denied gracefully' {
			Mock Remove-Item { throw 'Access denied' }

			{ Remove-StaleFiles -Path $TestPath -Age 10 -Force -WarningAction SilentlyContinue } | Should -Not -Throw
		}

		It 'Should continue processing after individual file failures' {
			$File1 = Join-Path $TestPath 'file1.txt'
			$File2 = Join-Path $TestPath 'file2.txt'

			'content1' | Out-File -FilePath $File1
			'content2' | Out-File -FilePath $File2

			$OldDate = (Get-Date).AddDays(-15)
			(Get-Item $File1).LastWriteTime = $OldDate
			(Get-Item $File2).LastWriteTime = $OldDate

			Mock Remove-Item {
				if ($Path -eq $File1) { throw 'Access denied' }
			} -ParameterFilter { $Path -eq $File1 }

			Remove-StaleFiles -Path $TestPath -Age 10 -Force -WarningAction SilentlyContinue

			Test-Path $File1 | Should -Be $false
			Test-Path $File2 | Should -Be $false
		}
	}

	Context 'Output and Reporting' {
		It 'Should report no stale files when none exist' {
			$Output = Remove-StaleFiles -Path $TestPath -Age 30 -Force 6>&1

			$Output | Should -Match 'No stale files found'
		}

		It 'Should provide verbose output about files being processed' {
			$Output = Remove-StaleFiles -Path $TestPath -Age 10 -Force -Verbose 4>&1 | Out-String

			$Output | Should -Match 'Scanning for files older than'
			$Output | Should -Match 'Processing path:'
		}
	}

	Context 'System Path Safety Checks' {
		BeforeAll {
			# Create a mock system directory for safe testing
			$MockSystemPath = Join-Path $TestDrive 'MockSystemPath'
			New-Item -Path $MockSystemPath -ItemType Directory -Force | Out-Null
			
			# Extract Test-SystemPath function for direct testing
			$FunctionContent = Get-Content $PSScriptRoot\..\functions\Remove-StaleFiles.ps1 -Raw
			
			# Create Test-SystemPath function in current scope for testing
			$TestSystemPathStart = $FunctionContent.IndexOf('function Test-SystemPath {')
			$BraceCount = 0
			$InFunction = $false
			$FunctionEnd = -1
			
			for ($i = $TestSystemPathStart; $i -lt $FunctionContent.Length; $i++) {
				$char = $FunctionContent[$i]
				if ($char -eq '{') {
					$BraceCount++
					$InFunction = $true
				}
				elseif ($char -eq '}') {
					$BraceCount--
					if ($InFunction -and $BraceCount -eq 0) {
						$FunctionEnd = $i
						break
					}
				}
			}
			
			if ($FunctionEnd -gt 0) {
				$TestSystemPathFunction = $FunctionContent.Substring($TestSystemPathStart, $FunctionEnd - $TestSystemPathStart + 1)
				Invoke-Expression $TestSystemPathFunction
			}
		}

		It 'Should prevent execution on system paths without AllowSystemPaths' {
			# Test with a mock path that simulates system directory detection
			Mock Test-SystemPath { return $true }
			
			{ Remove-StaleFiles -Path $MockSystemPath -Age 10 -ErrorAction Stop } | Should -Throw -ExpectedMessage '*system directory*'
		}

		It 'Should allow execution with AllowSystemPaths parameter' {
			# Test with a mock path that simulates system directory detection
			Mock Test-SystemPath { return $true }
			
			{ Remove-StaleFiles -Path $MockSystemPath -Age 10 -AllowSystemPaths -WhatIf } | Should -Not -Throw
		}

		It 'Should allow non-system paths to execute normally' {
			# Test with a safe path that is not a system directory
			{ Remove-StaleFiles -Path $TestPath -Age 10 -WhatIf } | Should -Not -Throw
		}
	}

	Context 'Test-SystemPath Function Unit Tests' {
		BeforeAll {
			# Extract Test-SystemPath function for direct testing
			$FunctionContent = Get-Content $PSScriptRoot\..\functions\Remove-StaleFiles.ps1 -Raw
			
			# Create Test-SystemPath function in current scope for testing
			$TestSystemPathStart = $FunctionContent.IndexOf('function Test-SystemPath {')
			$BraceCount = 0
			$InFunction = $false
			$FunctionEnd = -1
			
			for ($i = $TestSystemPathStart; $i -lt $FunctionContent.Length; $i++) {
				$char = $FunctionContent[$i]
				if ($char -eq '{') {
					$BraceCount++
					$InFunction = $true
				}
				elseif ($char -eq '}') {
					$BraceCount--
					if ($InFunction -and $BraceCount -eq 0) {
						$FunctionEnd = $i
						break
					}
				}
			}
			
			if ($FunctionEnd -gt 0) {
				$TestSystemPathFunction = $FunctionContent.Substring($TestSystemPathStart, $FunctionEnd - $TestSystemPathStart + 1)
				Invoke-Expression $TestSystemPathFunction
			}
		}

		It 'Should detect Windows system paths correctly' {
			if ($IsWindows -or $env:OS -eq 'Windows_NT') {
				# Test drive roots
				Test-SystemPath -TestPath 'C:\' | Should -Be $true
				
				# Test system directories using environment variables (if they exist)
				if ($env:SystemRoot) {
					Test-SystemPath -TestPath $env:SystemRoot | Should -Be $true
				}
				if ($env:ProgramFiles) {
					Test-SystemPath -TestPath $env:ProgramFiles | Should -Be $true
				}
			}
		}

		It 'Should detect Unix/Linux system paths correctly' {
			if ($IsLinux -or $IsMacOS -or (!$IsWindows -and $env:OS -ne 'Windows_NT')) {
				Test-SystemPath -TestPath '/' | Should -Be $true
				Test-SystemPath -TestPath '/etc' | Should -Be $true
				Test-SystemPath -TestPath '/bin' | Should -Be $true
				Test-SystemPath -TestPath '/usr' | Should -Be $true
			}
		}

		It 'Should return false for safe user directories' {
			# Test with temp directory (always safe)
			$TempPath = [System.IO.Path]::GetTempPath()
			Test-SystemPath -TestPath $TempPath | Should -Be $false
			
			# Test with typical user paths
			if ($IsWindows -or $env:OS -eq 'Windows_NT') {
				Test-SystemPath -TestPath 'C:\Users\TestUser\Documents' | Should -Be $false
				Test-SystemPath -TestPath 'C:\Temp' | Should -Be $false
			} else {
				Test-SystemPath -TestPath '/home/testuser' | Should -Be $false
				Test-SystemPath -TestPath '/tmp' | Should -Be $false
			}
		}

		It 'Should return false for subdirectories of blocked paths' {
			if ($IsWindows -or $env:OS -eq 'Windows_NT') {
				# Subdirectories should be allowed
				Test-SystemPath -TestPath 'C:\Windows\Temp' | Should -Be $false
				Test-SystemPath -TestPath 'C:\Program Files\MyApp' | Should -Be $false
			} else {
				Test-SystemPath -TestPath '/etc/myconfig' | Should -Be $false
				Test-SystemPath -TestPath '/usr/local' | Should -Be $false
			}
		}

		It 'Should handle path normalization correctly' {
			if ($IsWindows -or $env:OS -eq 'Windows_NT') {
				# Test different path formats for same location
				Test-SystemPath -TestPath 'C:\' | Should -Be $true
				Test-SystemPath -TestPath 'C:' | Should -Be $true
			}
		}

		It 'Should return false for non-existent but safe path patterns' {
			# These paths don't exist but follow safe patterns
			Test-SystemPath -TestPath '/home/nonexistent/folder' | Should -Be $false
			Test-SystemPath -TestPath 'C:\Users\NonExistent\Folder' | Should -Be $false
		}
	}

	Context 'WhatIf Integration Tests' {
		It 'Should show what would be removed with WhatIf' {
			$Output = Remove-StaleFiles -Path $TestPath -Age 10 -WhatIf 6>&1 | Out-String
			$Output | Should -Match 'WhatIf.*Would remove.*items'
		}

		It 'Should not modify any files when using WhatIf' {
			$FilesBefore = Get-ChildItem -Path $TestPath -Recurse | Measure-Object | Select-Object -ExpandProperty Count
			Remove-StaleFiles -Path $TestPath -Age 1 -WhatIf
			$FilesAfter = Get-ChildItem -Path $TestPath -Recurse | Measure-Object | Select-Object -ExpandProperty Count
			
			$FilesAfter | Should -Be $FilesBefore
		}

		It 'Should work with WhatIf and AllowSystemPaths on safe test directory' {
			# Create a directory that simulates system path behavior but is safe
			$SafeTestDir = Join-Path $TestDrive 'SafeSystemLikeDir'
			New-Item -Path $SafeTestDir -ItemType Directory -Force | Out-Null
			
			'test content' | Out-File -FilePath (Join-Path $SafeTestDir 'test.txt')
			(Get-Item (Join-Path $SafeTestDir 'test.txt')).LastWriteTime = (Get-Date).AddDays(-15)
			
			{ Remove-StaleFiles -Path $SafeTestDir -Age 10 -AllowSystemPaths -WhatIf } | Should -Not -Throw
		}
	}
}
