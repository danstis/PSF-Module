function Get-oAuthToken {
    <#
	.SYNOPSIS
	   Function to connect to the Microsoft login OAuth endpoint and return an OAuth token.
	.DESCRIPTION
	   This Function connects to the Microsoft AAD OAuth endpoint and generates an OAuth token.
	   This token can then be used for authentication against the resource supplied In the parameters.
	.PARAMETER ApplicationId
		The ApplicationId of the application used for authentication against Azure AD.
	.PARAMETER ApplicationKey
		The Key generated within the application used for authentication against Azure AD.
		This key should have rights to the resource supplied in the ResourceName parameter.
	.PARAMETER TenantId
		The TenantId of the Azure AD that you wish to authenticate against.
	.PARAMETER ResourceName
		The name of the resource that you want to generate a token for.
	.EXAMPLE
	   Get-ApiToken -ApplicationId '12345678-9012-3456-7890-123456789012' -ApplicationKey 'AfXooIr8rswX24yrFXMrO4SbBgutwTtojAZEpQOaaaa=' -TenantId 'abcd4ffb-d0bc-1234-854a-114710c94dbb' -Resource 'https://test.onmicrosoft.com/apitest'
	.NOTES
		Version 1.2.0
	#>
    [Cmdletbinding()]
    Param(
        [Parameter(Mandatory = $true)][string]$ApplicationId,
        [Parameter(Mandatory = $true)][string]$ApplicationKey,
        [Parameter(Mandatory = $true)][string]$TenantId,
        [Parameter(Mandatory = $false)][string]$ResourceName = "https://graph.windows.net",
        [Parameter(Mandatory = $false)][boolean]$ChinaAuth = $false
    )

    #This script will require the Web Application and permissions configured in Azure Active Directory.
    if ($ChinaAuth) {
        $LoginURL	= 'https://login.chinacloudapi.cn'
        $ResourceName = $ResourceName.replace("windows.net", "chinacloudapi.cn")
    }
    else {
        $LoginURL	= 'https://login.windows.net'
    }

    #Get an Oauth 2 access token based on client id, secret and tenant id
    $Body = @{grant_type = "client_credentials"; resource = $ResourceName; client_id = $ApplicationId; client_secret = $ApplicationKey}
    $AuthContext = Invoke-RestMethod -Method Post -Uri $LoginURL/$TenantId/oauth2/token?api-version=1.0 -Body $Body
    Return "$($AuthContext.token_type) $($AuthContext.access_token)"
}

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