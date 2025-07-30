# PSF-Module

[![Build and Deploy](https://github.com/danstis/PSF-Module/actions/workflows/deploy.yml/badge.svg)](https://github.com/danstis/PSF-Module/actions/workflows/deploy.yml)

A self-contained PowerShell module providing a set of utility functions, organized for easy import and publishing to the PowerShell Gallery.

[View on PowerShell Gallery](https://www.powershellgallery.com/packages/PSF)

---

## Project Overview

- **Main entry point:** `PSF.psm1` (imports all functions from `functions/`)
- **Module manifest:** `PSF.psd1` (controls exported functions and metadata)
- **CI/CD:** Automated with GitHub Actions (`.github/workflows/deploy.yml`)

## Directory Structure

```text
PSF.psm1                # Module entry point
PSF.psd1                # Module manifest
functions/              # Each function as a separate .ps1 file
  Get-oAuthToken.ps1
  Get-PublicIP.ps1
  Get-RandomPassword.ps1
  Get-Updates.ps1

tests/                  # Pester tests for each function
  Get-RandomPassword.Tests.ps1
.github/workflows/      # CI/CD pipeline
  deploy.yml
```

## Usage

Install from the PowerShell Gallery:

```powershell
Install-Module -Name PSF
```

Import the module:

```powershell
Import-Module PSF
```

## Adding a New Function

1. Create `functions/New-Function.ps1`.
2. Dot-source it in `PSF.psm1`.
3. Add to `FunctionsToExport` in `PSF.psd1`.
4. Add `tests/New-Function.Tests.ps1` (use Pester).

## Testing & Validation

- **Run all tests:**

  ```powershell
  .\.ExecuteTests.ps1
  ```

- **Validate manifest:**

  ```powershell
  Test-ModuleManifest -Path .\PSF.psd1
  ```

## CI/CD Pipeline

- On push/PR to `master`, the workflow:
  - Runs tests and validates the manifest
  - Versions the module using GitVersion
  - Tags the release
  - Publishes to the PowerShell Gallery

## Conventions

- Only functions listed in `FunctionsToExport` in `PSF.psd1` are public
- Only functions dot-sourced in `PSF.psm1` are loaded
- No wildcards in export lists
- Each function should have a corresponding test file
- No external dependencies (except standard PowerShell modules and GitHub Actions)

## License

[MIT](LICENSE)
