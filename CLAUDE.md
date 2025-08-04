# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

PSF-Module is a PowerShell utility module published to the PowerShell Gallery. It follows a specific architecture where each function is implemented as a separate file in the `functions/` directory and explicitly imported through `PSF.psm1`. The module manifest (`PSF.psd1`) controls which functions are exported publicly.

## Common Commands

### Testing

- **Run all tests:** `pwsh .\.ExecuteTests.ps1`
- **Validate module manifest:** `Test-ModuleManifest -Path .\PSF.psd1`

### Module Development

- **Test module import locally:** `Import-Module .\PSF.psd1 -Force`
- **Check exported functions:** `Get-Command -Module PSF`

## Architecture & Module Structure

### Critical Files Synchronization

The module requires three files to stay synchronized when adding/modifying functions:

1. **`functions/FunctionName.ps1`** - Function implementation
2. **`PSF.psm1`** - Must dot-source the function: `. $PSScriptRoot\functions\FunctionName.ps1`
3. **`PSF.psd1`** - Must list function in `FunctionsToExport` array

### Module Loading Pattern

- `PSF.psm1` explicitly dot-sources each function file (no wildcards)
- Only functions listed in `FunctionsToExport` in the manifest are publicly available
- Functions not in both places will either not load or not be accessible

### Testing Structure

- Each function should have a corresponding test file: `tests/FunctionName.Tests.ps1`
- Tests use Pester framework
- The `.ExecuteTests.ps1` script auto-installs Pester if missing

## CI/CD Pipeline

### Versioning

- Uses GitVersion with conventional commit patterns:
  - `(BREAKING CHANGES?|major)`: Major version bump
  - `(feature|minor|feat)`: Minor version bump
  - `(fix|patch|hotfix)`: Patch version bump
  - `(build|chore|ci|doc|docs|none|perf|refactor|skip|test)`: No version bump

### Deployment Process

1. Tests run on push/PR to master
2. On master branch: GitVersion calculates new version
3. Module manifest updated with new version and current year
4. Module files staged to `Modules/PSF/` directory
5. Published to PowerShell Gallery using `Publish-Module`

## Adding New Functions

When adding a new function, you must update all three locations:

1. Create `functions/New-FunctionName.ps1`
2. Add `. $PSScriptRoot\functions\New-FunctionName.ps1` to `PSF.psm1`
3. Add `'New-FunctionName'` to `FunctionsToExport` array in `PSF.psd1`
4. Create `tests/New-FunctionName.Tests.ps1` with Pester tests

## Key Constraints

- No external dependencies beyond standard PowerShell modules
- No wildcards in function exports (explicit listing required)
- Avoid functions that trigger antivirus false positives
- Module is self-contained for PowerShell Gallery distribution
