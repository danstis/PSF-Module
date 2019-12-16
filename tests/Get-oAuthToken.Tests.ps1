#Requires -Modules Pester

Import-Module $PSScriptRoot\..\PSF.psm1 -Force

Describe 'Get-oAuthToken' {

	Context "When called normally" {
		Mock -ModuleName PSF Invoke-RestMethod { return [PSCustomObject]@{ token_type = "Bearer"; access_token = "StandardEndpoint" } } -ParameterFilter { $Uri.AbsoluteUri.StartsWith("https://login.windows.net") } # Mock the standard endpoint calls.

		$Result = Get-oAuthToken -ApplicationId "00000000-0000-0000-0000-000000000000" -ApplicationKey "Test" -TenantId "00000000-0000-0000-0000-000000000000" -ResourceName "https://test"

		It "Returns a valid token from the correct endpoint" {
			$Result | Should -Be "Bearer StandardEndpoint"
		}

		It "Calls calls the oAuth endpoint" {
			Assert-MockCalled -ModuleName PSF -CommandName Invoke-RestMethod -Times 1
		}
	}

	Context "When called with ChinaAuth" {
		Mock -ModuleName PSF Invoke-RestMethod { return [PSCustomObject]@{ token_type = "Bearer"; access_token = "ChinaEndpoint" } } -ParameterFilter { $Uri.AbsoluteUri.StartsWith("https://login.chinacloudapi.cn") } # Mock the china endpoint calls.

		$Result = Get-oAuthToken -ApplicationId "00000000-0000-0000-0000-000000000000" -ApplicationKey "Test" -TenantId "00000000-0000-0000-0000-000000000000" -ResourceName "https://test" -ChinaAuth $true

		It "Returns a valid token from the correct endpoint" {
			$Result | Should -Be "Bearer ChinaEndpoint"
		}

		It "Calls calls the oAuth endpoint" {
			Assert-MockCalled -ModuleName PSF -CommandName Invoke-RestMethod -Times 1
		}
	}

}
