function Connect-AadWithRmContext {
	<#
	.SYNOPSIS
	   Connect to Azure AD using an existing Azure RM Context.
	.DESCRIPTION
	   This Function connects to the Microsoft AAD using an existing Azure RM context by
	   leveraging the exiting oAuth token for Azure RM.
	.EXAMPLE
	   Connect-AadWithRmContext
	.NOTES
		Version 1.0.1
	#>

	$Context = Get-AzureRmContext
	# Force context to grab a token for GraphAPI
	Get-AzureRmADUser -UserPrincipalName $Context.Account.Id

	$CacheItems = $Context.TokenCache.ReadItems()

	$Token = ($CacheItems | Where-Object { $_.Resource -eq "https://graph.windows.net/" -and $_.TenantId -eq $Context.Tenant.Id })
	if ($Token.ExpiresOn -le [System.DateTime]::UtcNow) {
		$AC = [Microsoft.IdentityModel.Clients.ActiveDirectory.AuthenticationContext]::new("$($Context.Environment.ActiveDirectoryAuthority)$($Context.Tenant.Id)", $Token)
		$Token = $AC.AcquireTokenByRefreshToken($Token.RefreshToken, "1950a258-227b-4e31-a9cf-717495945fc2", "https://graph.windows.net")
	}
	Connect-AzureAD -AadAccessToken $Token.AccessToken -AccountId $Context.Account.Id -TenantId $Context.Tenant.Id | Out-Null
}
