function Get-oAuthToken {
	<#
	.SYNOPSIS
	   Function to connect to the Microsoft login OAuth endpoint and return an OAuth token.
	.DESCRIPTION
	   This Function connects to the Microsoft AAD OAuth endpoint and generates an OAuth token.
	   This token can then be used for authentication against the resource supplied In the parameters.
	.PARAMETER ClientID
		The ClientID of the application used for authentication against Azure AD.
	.PARAMETER ClientSecret
		The Key generated within the application used for authentication against Azure AD.
		This key should have rights to the resource supplied in the ResourceName parameter.
	.PARAMETER TenantId
		The TenantId of the Azure AD that you wish to authenticate against.
	.PARAMETER ResourceName
		The name of the resource that you want to generate a token for.
	.EXAMPLE
	   Get-ApiToken -ClientID '12345678-9012-3456-7890-123456789012' -ClientSecret 'abcdefghijklmnopqrstuvwxyz==' -TenantId 'abcd4ffb-d0bc-1234-854a-114710c94dbb' -Resource 'https://test.onmicrosoft.com/apitest'
	.NOTES
		Version 2.0
	#>
	[Cmdletbinding()]
	Param(
		[Parameter(Mandatory = $true)][string]$ClientID,
		[Parameter(Mandatory = $true)][string]$ClientSecret,
		[Parameter(Mandatory = $true)][string]$TenantId,
		[Parameter(Mandatory = $false)][string]$ResourceName = 'https://graph.microsoft.com/.default',
		[Parameter(Mandatory = $false)][boolean]$ChinaAuth = $false,
		[Parameter(Mandatory = $false)][boolean]$IncludeType = $true
	)

	#This script will require the Web Application and permissions configured in Azure Active Directory.
	if ($ChinaAuth) {
		$LoginURL	= 'https://login.chinacloudapi.cn'
		$ResourceName = $ResourceName.replace('microsoft.com', 'chinacloudapi.cn')
	} else {
		$LoginURL	= 'https://login.microsoftonline.com'
	}

	#Get an Oauth 2 access token based on client id, secret and tenant id
	$Body = @{grant_type = 'client_credentials'; scope = $ResourceName; client_id = $ClientID; client_secret = $ClientSecret }
	$AuthContext = Invoke-RestMethod -Method Post -Uri $LoginURL/$TenantId/oauth2/v2.0/token -Body $Body
	if ($IncludeType) {
		Return ('{0} {1}' -f $AuthContext.token_type, $AuthContext.access_token)
	}
	Return $AuthContext.access_token
}
