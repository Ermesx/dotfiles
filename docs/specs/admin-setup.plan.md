# Admin Setup Aggregate and Reminder Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** An administrator runs one script (or one per item) for the machine-level setup, the user finishes with one profile function, and every `chezmoi apply` ends with a one-line reminder while the administrator step is missing.

**Architecture:** `admin-setup.ps1` sits next to the three item scripts in `home/dot_config/dotfiles/admin/`, dot-sources them from `$PSScriptRoot` under `Stop`, then prints a two-line recap pointing at `Complete-UserSetup`, a profile function that installs the WSL distro and loads the SSH key. A plain `run_after_zz-admin-reminder` script probes the three machine states with the same tests the user-side skip scripts use and, if any is missing, prints one absolute `pwsh -File` command for `admin-setup.ps1`.

**Tech Stack:** PowerShell 7, chezmoi 2.73 templates, Pester 6.

**Spec:** [`docs/specs/admin-setup.md`](admin-setup.md) (R1–R13, decisions C1–C8 and D1–D6 confirmed; D5 rejected). ADR: [ADR-0003](../adr/0003-windows-packages-via-scoop.md).

## Global Constraints

- Branch `feat/44-admin-setup` off `develop`. Conventional Commits with a scope; the docs commit carries `Fixes #44`.
- `*.ps1`, `*.ps1.tmpl`: **CRLF**, no BOM. Check: `git add <f>; git ls-files --eol <f>` → `i/crlf`. Everything else LF.
- Never run `chezmoi apply`, `install.ps1` or any real script from `home/dot_config/dotfiles/admin/` on the host. Host checks: render, parse, Pester, and running the (read-only) reminder.
- Always `chezmoi --source .` from the repo root.
- Progress lines: `Write-Host "► <Action>" -ForegroundColor Cyan`; reminder and next-step headers Yellow.
- No `Get-Command` guards; probes check target state only.
- Render + parse check (`<f>` = source path; for a plain `.ps1` skip the render):
  `pwsh -NoProfile -Command '$t = Get-Content -Raw <f> | chezmoi --source . execute-template; $e=$null; [void][System.Management.Automation.Language.Parser]::ParseInput(($t -join "`n"),[ref]$null,[ref]$e); "errors=" + @($e).Count'` → `errors=0`.
- Pester command (host): `pwsh -NoProfile -Command 'Import-Module Pester -MinimumVersion 6.0.0; Invoke-Pester tests/windows/AdminSetup -Output Detailed'`.
- Test header as in `tests/windows/PackageUpdates/*.Tests.ps1`: `#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '6.0.0' }`; native commands get a `function global:<name> { }` stub before `Mock`.

## Review Focus

1. **Path printed for the wrong user or unquoted** (administrator's `~`, a user name with a space) → R7; Task 3 test `prints an absolute, quoted path under the user's profile`.
2. **Reminder and skip scripts disagree on a state** → same probes (R6); Task 3 Step 5 greps the probe expressions in both places.
3. **Aggregate prints the recap after a failure** (reads like success to IT) → D2; Task 2 test `stops at the first failing item and prints no recap`.
4. **Reminder breaks apply** (the service is absent) → R9; Task 3 test `exits 0 when the ssh-agent service does not exist`.
5. **Aggregate started from another directory** does not find its siblings → R2; Task 2 tests run it with the working directory set to the `TestDrive:` root, not the script's folder.

---

### Task 1: Profile function `Complete-UserSetup`

**Files:**
- Create: `home/dot_profile/user-setup_profile.ps1.tmpl`
- Test: `tests/windows/AdminSetup/Complete-UserSetup.Tests.ps1`

**Interfaces:**
- Consumes: `.packages.windows.profiles.sdk.wsl`.
- Produces: `Complete-UserSetup` (no parameters), named by the admin scripts (Task 2) and the ReadMe (Task 4).

- [ ] **Step 1: Write `Complete-UserSetup.Tests.ps1`.** `BeforeAll`: `$root = Resolve-Path "$PSScriptRoot/../../.."`; `$distro = (chezmoi --source $root data --format json | ConvertFrom-Json).packages.windows.profiles.sdk.wsl`; render `home/dot_profile/user-setup_profile.ps1.tmpl` with `chezmoi --source $root execute-template` into `TestDrive:\user-setup.ps1` and dot-source it; `function global:wsl { }`, `function global:ssh-add { }`. `BeforeEach`: `Mock ssh-add { }`, `Mock Write-Host { }`.
  - `It 'skips the distro install when the distro is listed'`: `Mock wsl { $distro }` → `Should -Invoke wsl -Times 0 -ParameterFilter { $args -contains '--install' }`.
  - `It 'installs the distro when it is missing'`: `Mock wsl { }` → `Should -Invoke wsl -Times 1 -ParameterFilter { ($args -join ' ') -eq "--install -d $distro --web-download --no-launch" }`.
  - `It 'loads the SSH key'`: `Should -Invoke ssh-add -Times 1 -ParameterFilter { $args[0] -eq (Join-Path $HOME '.ssh' 'id_ed25519') }`.
- [ ] **Step 2: Run Pester, expect FAIL** (fragment missing). If the mocks of `wsl` / `ssh-add` cannot match `$args`, stop and report (spec Risks).
- [ ] **Step 3: Create `user-setup_profile.ps1.tmpl`** per R13 (CRLF):

  ```powershell
  # Per-user part of the admin setup: run as yourself after the administrator step and a restart
  function Complete-UserSetup {
      # WSL distros are per user, so the administrator's script only enables the platform
      $distro = {{ .packages.windows.profiles.sdk.wsl | squote }}
      # wsl prints UTF-16 unless WSL_UTF8 is set; without it -contains never matches
      $env:WSL_UTF8 = '1'
      if (-not ((wsl -l -q) -contains $distro)) {
          Write-Host "► Installing WSL $distro" -ForegroundColor Cyan
          wsl --install -d $distro --web-download --no-launch
      }

      # The agent keeps keys per user
      Write-Host "► Add ssh key" -ForegroundColor Cyan
      ssh-add (Join-Path $HOME '.ssh' 'id_ed25519')
  }
  ```
- [ ] **Step 4: Run Pester → PASS; render + parse → `errors=0`.** If the hook asks for the `docs-sync` agent after the `home/dot_profile/` edit, run it (expected: no change, the function is not a key binding).
- [ ] **Step 5: Commit** `feat(profile): add Complete-UserSetup for the per-user WSL and SSH steps`.

### Task 2: Aggregate `admin-setup.ps1` and the item scripts' next steps

**Files:**
- Create: `home/dot_config/dotfiles/admin/admin-setup.ps1`
- Rename: `home/dot_config/dotfiles/admin/enable-wsl.ps1.tmpl` → `enable-wsl.ps1` (`git mv`)
- Modify: `enable-wsl.ps1`, `enable-ssh-agent.ps1` (next-step lines only)
- Test: `tests/windows/AdminSetup/Admin-Setup.Tests.ps1`

**Interfaces:**
- Consumes: `Complete-UserSetup` (Task 1, by name only).
- Produces: `~/.config/dotfiles/admin/admin-setup.ps1`, named by the reminder (Task 3) and the ReadMe (Task 4).

- [ ] **Step 1: Write `Admin-Setup.Tests.ps1`.** `BeforeAll`: `$source = Resolve-Path "$PSScriptRoot/../../../home/dot_config/dotfiles/admin/admin-setup.ps1"`; helper `Invoke-Aggregate([string]$failing)` creates `TestDrive:\<guid>\admin\`, copies the aggregate there, writes three stubs `enable-developer-mode.ps1`, `enable-ssh-agent.ps1`, `enable-wsl.ps1`, each `Add-Content (Join-Path $PSScriptRoot 'log.txt') '<name>'`, the one named `$failing` then `Write-Error 'denied'` (non-terminating: the test proves `Stop` applies); runs `pwsh -NoProfile -File <dir>\admin-setup.ps1 *>&1 | Out-String` from `Push-Location $TestDrive` (a different directory, Review Focus 5); returns output, `$LASTEXITCODE` and the log lines.
  - `It 'runs the three items in order'`: log equals `enable-developer-mode`, `enable-ssh-agent`, `enable-wsl`; exit code `0`.
  - `It 'ends with the per-user recap'`: output matches `Next steps`, contains `Restart the computer` and `Complete-UserSetup`.
  - `It 'stops at the first failing item and prints no recap'` (failing = `enable-ssh-agent`): log equals `enable-developer-mode`, `enable-ssh-agent`; exit code not `0`; output does not match `Next steps`.
- [ ] **Step 2: Run Pester, expect FAIL** (aggregate missing).
- [ ] **Step 3: Create `admin-setup.ps1`** per R1–R3 (CRLF, no BOM):

  ```powershell
  # Runs every admin-only setup script in this folder. Run as administrator (PowerShell 7).
  # Review the three scripts it runs: they sit in a user-writable folder.
  $ErrorActionPreference = 'Stop'

  # Dot-sourced from this script's folder: works from any current directory, and Stop applies to them directly
  . "$PSScriptRoot\enable-developer-mode.ps1"
  . "$PSScriptRoot\enable-ssh-agent.ps1"
  . "$PSScriptRoot\enable-wsl.ps1"

  Write-Host "► Next steps (as the user, not as administrator)" -ForegroundColor Yellow
  Write-Host "  1. Restart the computer."
  Write-Host "  2. In a new PowerShell window: Complete-UserSetup"
  ```
- [ ] **Step 4: Item scripts (R4).** `git mv enable-wsl.ps1.tmpl enable-wsl.ps1`; its next steps become `1. Restart the computer.` and `2. As the user, not as administrator, in a new PowerShell window: Complete-UserSetup`. `enable-ssh-agent.ps1`: next step `As the user, not as administrator: Complete-UserSetup`. Header comments still say the distro / key is per user. CRLF.
- [ ] **Step 5: Run Pester → PASS; parse the three changed scripts → `errors=0`; `chezmoi --source . managed` lists `.config/dotfiles/admin/admin-setup.ps1` and `.config/dotfiles/admin/enable-wsl.ps1`; `git grep -n "wsl --install -d" -- home` → only `user-setup_profile.ps1.tmpl` and `run_once_before_install-wsl.ps1.tmpl`.**
- [ ] **Step 6: Commit** `feat(admin): add admin-setup.ps1 to run all admin scripts`.

### Task 3: End-of-apply reminder

**Files:**
- Create: `home/.chezmoiscripts/windows/run_after_zz-admin-reminder.ps1`
- Test: `tests/windows/AdminSetup/Admin-Reminder.Tests.ps1`

**Interfaces:**
- Consumes: `admin-setup.ps1` from Task 2 (by name).
- Produces: target `.chezmoiscripts/windows/zz-admin-reminder.ps1`.

- [ ] **Step 1: Write `Admin-Reminder.Tests.ps1`.** `BeforeAll`: `$script = Resolve-Path "$PSScriptRoot/../../../home/.chezmoiscripts/windows/run_after_zz-admin-reminder.ps1"`; `function global:wsl { }`; `$expected = Join-Path $HOME '.config\dotfiles\admin\admin-setup.ps1'`. `BeforeEach` mocks the all-present state: `Mock Get-ItemProperty { [pscustomobject]@{ AllowDevelopmentWithoutDevLicense = 1 } }`, `Mock Get-Service { [pscustomobject]@{ Status = 'Running' } }`, `Mock wsl { $global:LASTEXITCODE = 0 }`. Run: `$out = & $script 6>&1 | Out-String`.
  - `It 'prints nothing when all three are present'`: `$out.Trim() | Should -BeNullOrEmpty`.
  - `It 'reminds when <item> is missing'` with `-ForEach` over three cases (DWORD `0`; `wsl` sets `LASTEXITCODE = 1`; `Status = 'Stopped'`): output contains `Administrator step needed` and `admin-setup.ps1`, and no `enable-` (D4).
  - `It 'prints an absolute, quoted path under the user's profile'`: any item missing → output contains `-File "$expected"` and neither `~` nor the literal text `$HOME`.
  - `It 'exits 0 when the ssh-agent service does not exist'`: `Mock Get-Service { }` → output contains `admin-setup.ps1`; `$LASTEXITCODE | Should -Be 0`.
- [ ] **Step 2: Run Pester, expect FAIL** (script missing).
- [ ] **Step 3: Create `run_after_zz-admin-reminder.ps1`** per R5–R9 (CRLF):

  ```powershell
  # Reminds that the admin-only setup is missing; never runs it and never fails apply.
  # The probes match the ones the user-side scripts use to skip, so the two never disagree.

  # Developer Mode: a standard user can read HKLM
  $devMode = (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock' `
      -Name AllowDevelopmentWithoutDevLicense -ErrorAction SilentlyContinue).AllowDevelopmentWithoutDevLicense -eq 1

  # WSL platform: same check as run_once_before_install-wsl
  wsl --status *> $null
  $wsl = $LASTEXITCODE -eq 0

  # ssh-agent service: same check as run_once_after_add-ssh-key
  $agent = (Get-Service ssh-agent -ErrorAction SilentlyContinue).Status -eq 'Running'

  if (-not ($devMode -and $wsl -and $agent)) {
      # Absolute path from the user's profile: an administrator's ~ would point to their own profile
      $script = Join-Path $HOME '.config\dotfiles\admin\admin-setup.ps1'
      Write-Host "► Administrator step needed" -ForegroundColor Yellow
      Write-Host "  Run as an administrator: pwsh -NoProfile -ExecutionPolicy Bypass -File `"$script`""
  }
  exit 0
  ```
- [ ] **Step 4: Run Pester → PASS; parse → `errors=0`.**
- [ ] **Step 5: Probe parity:** `git grep -n -F -e "wsl --status" -e "Get-Service ssh-agent" -- home/.chezmoiscripts` → the same expressions in the reminder and in `run_once_before_install-wsl.ps1.tmpl` / `run_once_after_add-ssh-key.ps1`.
- [ ] **Step 6: Order and safety:** `chezmoi --source . managed --include=scripts` → `zz-admin-reminder.ps1` is the last `.chezmoiscripts/windows/` line; `git grep -n "dotfiles.admin" -- home/.chezmoiscripts` → only the string in the reminder.
- [ ] **Step 7: Host smoke run (read-only):** `pwsh -NoProfile -File home/.chezmoiscripts/windows/run_after_zz-admin-reminder.ps1; $LASTEXITCODE` → reminder exactly when at least one item is missing on this machine (compare with `Get-Service ssh-agent`, `wsl --status`, the HKLM value); exit `0`.
- [ ] **Step 8: Commit** `feat(admin): remind about missing admin setup after apply`.

### Task 4: Docs

**Files:**
- Modify: `ReadMe.md` (new section, R10), `docs/packages.md` (lines 11–15, R11), `docs/architecture.md` (admin row, R11), `docs/testing.md` (unit-test command, R11)

**Interfaces:**
- Consumes: names and output text from Tasks 1–3.

- [ ] **Step 1: ReadMe section "Administrator step (Windows)"** after the install instructions, per R10. Command form `pwsh -NoProfile -ExecutionPolicy Bypass -File "C:\Users\<you>\.config\dotfiles\admin\admin-setup.ps1"`; a short paragraph IT can be sent (review the four files; run from your own account; do not run the per-user step; restart); after the restart `Complete-UserSetup`; apply reminds until the administrator step is done. Do not edit the `<!-- BEGIN:packages -->` region.
- [ ] **Step 2: `docs/packages.md`, `docs/architecture.md`, `docs/testing.md`** per R11 (testing: add `tests/windows/AdminSetup` to the `Invoke-Pester` list; these tests need no `PSModulePath` prefix).
- [ ] **Step 3: Check:** `git grep -n "are #44"` → nothing; `git grep -n "enable-wsl.ps1.tmpl" -- ':!docs/specs/scoop-user-scope*' ':!docs/specs/admin-setup*'` → nothing; every command in the ReadMe section matches the scripts' output verbatim.
- [ ] **Step 4: Commit** `docs(admin): describe the administrator and per-user steps` with `Fixes #44` in the body.

### Task 5: Code review before the PR

- [ ] **Step 1:** run `/code-review` (skill `code-review`) on the branch against `develop`.
- [ ] **Step 2:** fix every confirmed finding; rerun the Pester command and the checks of Tasks 1–3; commit (`fix(admin): …`). A rejected finding goes into the PR description with the reason.

### Task 6: Pull request

- [ ] Push `feat/44-admin-setup` and open a PR to `develop`: scope, decisions D1–D6, host test results, code-review outcome, and the VM checklist of Task 7.

### Task 7: VM acceptance (owner, by hand)

Not automatable on the host (two accounts and a restart). Spec *Acceptance* 3–5 with `docs/testing.md`: the standard user runs `install.ps1` → apply exits 0, the WSL/SSH skip lines, the reminder with the absolute path; the administrator account runs each `enable-*` alone and `admin-setup.ps1`, twice each, recording what `wsl --install --no-distribution` / `wsl --update` print and return on the second run and what `wsl --status` returns before the restart; restart; the standard user runs `Complete-UserSetup` in a new PowerShell window; `wsl -l -q` lists the distro, `ssh-add -l` the key; the next apply prints no reminder. Results go into the PR description.
