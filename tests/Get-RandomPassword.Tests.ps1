#Requires -Modules Pester

Import-Module $PSScriptRoot\..\PSF.psm1 -Force

Describe 'Get-RandomPassword' {

	It 'Told to generate a 6 character password, the output contains 6 characters' {
		$Result = Get-RandomPassword -Length 6
		$Result.Length | Should -Be 6
	}

	It 'Told to generate a 20 character password, the output contains 20 characters' {
		$Result = Get-RandomPassword -Length 20
		$Result.Length | Should -Be 20
	}

	It 'Told to generate a SQL password, does not contain any of the excluded characters' {
		# Variable to track if a match was found
		$CharMatch = $false
		# Characters to exclude in SQL passwords
		[char[]]$ExcludedChars = "\`"'%$``,;Il0O1"
		$Result = Get-RandomPassword -Length 100 -SQL
		foreach ($Char in $ExcludedChars) {
			if ($Result.Contains($Char)) {$CharMatch = $true}
		}
		$CharMatch | Should -BeFalse
	}

	It 'Told to exclude a character, the generated result does not include it' {
		# Variable to track if a match was found
		$CharMatch = $false
		# Characters to exclude
		[char[]]$ExcludedChars = "abcdefghijklmnopqrstuvwxy" # Exclude all lowercase characters apart from 'z'
		$Result = Get-RandomPassword -Length 30 -Exclude $ExcludedChars -Charsets "L" # Generated password will be 30x 'z'
		foreach ($Char in $ExcludedChars) {
			if ($Result.Contains($Char)) {$CharMatch = $true}
		}
		$CharMatch | Should -BeFalse
	}

}
