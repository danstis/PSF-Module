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
