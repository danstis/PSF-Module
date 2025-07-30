# Copilot Instructions for PSF-Module

## Project Overview
- This is a PowerShell module providing a set of utility functions, organized for easy import and publishing to the PowerShell Gallery.
- The main entry point is `PSF.psm1`, which imports all functions from the `functions/` directory.
- The module manifest is `PSF.psd1`, which controls exported functions and metadata.

## Directory Structure
- `functions/` — Each function is implemented as a separate `.ps1` file. Only files listed in `PSF.psm1` are loaded.
- `tests/` — Pester test scripts for each function, named as `FunctionName.Tests.ps1`.
- `.github/workflows/deploy.yml` — GitHub Actions workflow for CI/CD, including test and publish steps.

## Build, Test, and Deploy
- **Tests:** Run with `pwsh` using `.\.ExecuteTests.ps1` (called in CI). Tests are expected to be in `tests/` and use Pester.
- **Manifest Validation:** Use `Test-ModuleManifest -Path .\PSF.psd1` to validate the module before publishing.
- **CI/CD:**
  - On push/PR to `master`, the workflow runs tests, updates the manifest version, tags the release, and publishes to the PowerShell Gallery using `Publish-Module`.
  - Versioning is managed by GitVersion.

## Conventions & Patterns
- **Function Export:** Only functions listed in `FunctionsToExport` in `PSF.psd1` are public.
- **Function Import:** Only functions explicitly dot-sourced in `PSF.psm1` are loaded.
- **No Wildcards:** Avoid wildcards in export lists for performance and clarity.
- **Tests:** Each function should have a corresponding test file in `tests/`.
- **No External Dependencies:** The module is self-contained except for standard PowerShell modules and GitHub Actions dependencies.

## Examples
- To add a new function:
  1. Create `functions/New-Function.ps1`.
  2. Dot-source it in `PSF.psm1`.
  3. Add to `FunctionsToExport` in `PSF.psd1`.
  4. Add `tests/New-Function.Tests.ps1`.

## Key Files
- `PSF.psm1` — Module entry, imports functions.
- `PSF.psd1` — Manifest, controls exports and metadata.
- `functions/` — Function implementations.
- `tests/` — Pester tests.
- `.github/workflows/deploy.yml` — CI/CD pipeline.

## Special Notes
- Avoid adding functions that trigger antivirus false positives.
- Keep the module manifest and function imports in sync.
- Use semantic versioning for releases.
