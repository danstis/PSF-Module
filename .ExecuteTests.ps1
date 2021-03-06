# If pester is not available, install it from PS Gallery
if ($null -eq (Get-Module -ListAvailable pester)) {
	Install-Module -Name Pester -Repository PSGallery -Force -Scope CurrentUser
}

Invoke-Pester -Script $PSScriptRoot\tests -Verbose
