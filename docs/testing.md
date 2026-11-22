# Testing

- The full install is tested only in the Vagrant VM. Only the Windows VM has a test runner.
- Inside the VM, `run-tests.ps1` downloads only `install.ps1` from GitHub (`.../refs/heads/<branch>/install.ps1`),
  so push changes to `install.ps1` before testing them.
- Dotfile content comes from your **local working copy**: the Vagrantfile syncs the repo root into the VM's chezmoi
  source dir, and `chezmoi init` skips cloning when that dir is already a git repo.
- Tests under `tests/windows/` that check a completed install (`Installed-Apps-Modules.Tests.ps1`) read the
  expected list from `chezmoi data`; no file is deployed to `$HOME`. They run only in the VM.
- Run the VM acceptance as a standard user (created by hand until #47), not as an administrator: that is what
  proves apply needs no admin rights. Run the admin scripts from a second, administrator account, as an IT
  administrator would.

## Unit tests against the working copy

Module tests (`tests/windows/Write-Pretty/`, `tests/windows/PackageUpdates/`) run on the host without applying
chezmoi: prepend the source module directory to `PSModulePath` in a child shell. Only Pester 6 is supported; the
test files enforce it with `#Requires`. Name the folders: `tests/windows` itself holds the VM-only install test.

```powershell
pwsh -NoProfile -Command 'Import-Module Pester -MinimumVersion 6.0.0; $env:PSModulePath = "$PWD\home\readonly_Documents\PowerShell\Modules;$env:PSModulePath"; Invoke-Pester tests/windows/Write-Pretty, tests/windows/PackageUpdates -Output Detailed'
```

Without the `PSModulePath` prefix, `Import-Module` loads the *installed* copy from `~/Documents`. The
`PackageUpdates` tests mock `scoop`, `dotnet`, the Gallery and NuGet; real updates are checked in the VM.

The admin-setup tests load scripts from the source, so they need no `PSModulePath` prefix. They mock `wsl`,
`ssh-add`, the service and the registry, and run the aggregate against stub item scripts; the real admin scripts
run only in the VM:

```powershell
pwsh -NoProfile -Command 'Import-Module Pester -MinimumVersion 6.0.0; Invoke-Pester tests/windows/AdminSetup -Output Detailed'
```
