# Testing

- The full install is tested only in the Vagrant VM. Only the Windows VM has a test runner.
- Inside the VM, `run-tests.ps1` downloads only `install.ps1` from GitHub (`.../refs/heads/<branch>/install.ps1`),
  so push changes to `install.ps1` before testing them.
- Dotfile content comes from your **local working copy**: the Vagrantfile syncs the repo root into the VM's chezmoi
  source dir, and `chezmoi init` skips cloning when that dir is already a git repo.
- Tests under `tests/windows/` that check a completed install (`Installed-Apps-Modules.Tests.ps1`) read the
  expected list from the package view with `chezmoi execute-template`; no file is deployed to `$HOME`. They run
  only in the VM.
- Run the VM acceptance as a standard user (created by hand until #47), not as an administrator: that is what
  proves apply needs no admin rights.
- `tests/windows/Package-View.Tests.ps1` checks the view itself and also runs on the host:

```powershell
pwsh -NoProfile -Command 'Import-Module Pester -MinimumVersion 6.0.0; Invoke-Pester tests/windows/Package-View.Tests.ps1 -Output Detailed'
```

## Unit tests against the working copy

Module tests (currently `tests/windows/Write-Pretty/`) run on the host without applying chezmoi: prepend the
source module directory to `PSModulePath` in a child shell. Only Pester 6 is supported; the Write-Pretty test file
enforces it with `#Requires`:

```powershell
pwsh -NoProfile -Command 'Import-Module Pester -MinimumVersion 6.0.0; $env:PSModulePath = "$PWD\home\readonly_Documents\PowerShell\Modules;$env:PSModulePath"; Invoke-Pester tests/windows/Write-Pretty -Output Detailed'
```

Without the `PSModulePath` prefix, `Import-Module Write-Pretty` loads the *installed* copy from `~/Documents`.
