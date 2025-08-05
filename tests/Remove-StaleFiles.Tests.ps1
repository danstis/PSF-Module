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
}
