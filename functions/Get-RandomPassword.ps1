Function Get-RandomPassword {
	<#
	.SYNOPSIS
		Generates random passwords.
	.DESCRIPTION
		Function to generate password based on character sets. Enables choice of password length and complexity.
	.EXAMPLE
		C:\PS> Get-RandomPassword
		Generates a 20 character complex password and copies the result to your clipboard.
	.EXAMPLE
		C:\PS> Get-RandomPassword 16 uln
		Generates a 16 character password with Upper (u), Lower (l) and Numbers (n) and copies the result to your clipboard.
	.PARAMETER Length
		Length of password to be generated.
		Default: 20
	.PARAMETER CharSets
		Choose which character sets to use. Options are U (upper case), L (lower case), N (number) and S (special characters).
		Default: ULNS
	.PARAMETER Exclude
		Exclude one or more characters from the password.
		Example: Get-RandomPassword -Exclude '#$' will exclude the # and $ characters from the password.
	.OUTPUTS
		A generated password.
	.NOTES
		Version 1.2.0
	#>

	Param(
		[Parameter(Mandatory = $false, HelpMessage = "PWLength", Position = 0)]
		[int] $Length = 20,
		[Parameter(Mandatory = $false, HelpMessage = "Character sets [U/L/N/S]", Position = 1)]
		[char[]] $CharSets = "ULNS",
		[Parameter(Mandatory = $false, Position = 2)]
		[char[]] $Exclude,
		[Parameter(Mandatory = $false)]
		[switch] $SQL
	)
	# Declare empty variables
	$Password = @()
	$AllNonExcludedCharacters = @()
	$SQLExcluded = '\',"'",'"','%','$','`',',',';','I','l','0','O','1'
	if ($SQL) {$Exclude = $SQLExcluded}
	# Create character arrays for U, L, N and S.
	$CharacterSetArray = @{
		U = [Char[]](65 .. 90)
		L = [Char[]](97 .. 122)
		N = [Char[]](48 .. 57)
		S = [Char[]](33 .. 46)
	}

	# For each character set (U, L, N, S) sent to the function.
	$CharSets | ForEach-Object {
		$NonExcludedTokens = @()
		# For each character in the character set array.
		$NonExcludedTokens = $CharacterSetArray."$_" | ForEach-Object {
			# Check to see if the character currently being looped is an excluded character (requested by the user).
			If ($Exclude -cNotContains $_) {
				# Add this character to the NonExcludedTokens array if not an excluded character.
				$_
			}
		}
		# If NonExcludedTokens contains any characters.
		If ($NonExcludedTokens) {
			# Add the characters to the AllNonExcludedCharacters array.
			$AllNonExcludedCharacters += $NonExcludedTokens
			# Append a random character from this NonExcludedTekons array to the password array.
			$Password += $NonExcludedTokens | Get-Random
		}
	}

	# Until the password array contains the same number of characters as the length parameter.
	While ($Password.Count -lt $Length) {
		# Add a random character from the AllNonExcludedCharacters array to the password array.
		$Password += $AllNonExcludedCharacters | Get-Random
	}

	# Randomise the characters in the Password array and join them as a single line. Output the line to screen and copy to clipboard.
	($Password | Sort-Object {Get-Random}) -Join "" | Tee-Object -v Output
	$Output | Clip
}

New-Alias -Name gpw -Value Get-RandomPassword
