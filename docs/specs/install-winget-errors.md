# Spec: `install.ps1` stops on a failed winget install and shows why

Issue: [#40](https://github.com/Ermesx/dotfiles/issues/40) · Status: Draft · Date: 2026-10-22 ·
Plan: [`install-winget-errors.plan.md`](install-winget-errors.plan.md)

## Problem

`install.ps1` runs `winget upgrade winget @params | Out-Null` and, in a loop, `winget install $_ @params | Out-Null`
for `twpayne.chezmoi`, `microsoft.dsc` and `microsoft.powershell`. The output is discarded and `$LASTEXITCODE` is
never read. A failed install (no rights, no network, source error) is invisible; the script goes on to
`chezmoi init --apply`, which fails later with an unrelated error when `dsc` or `pwsh` is missing.

The quiet output is intentional and stays: on success the user sees only the `► …` progress lines.

## Execution context (verified 2026-10-22)

The issue's notes assume PowerShell 7. That is not the bootstrap path:

- `ReadMe.md` starts the script with `iex (irm '…/install.ps1' | Out-String)`. On a fresh machine that is
  **Windows PowerShell 5.1**, because `microsoft.powershell` is one of the packages this script installs.
- `tests/run-tests.ps1` runs the same `iex (irm …)` line with `$ErrorActionPreference = "Stop"`; `iex` runs in the
  caller's scope, so `install.ps1` inherits `Stop`. The shell the VM user starts it from is not fixed by the
  repo (the Vagrantfile has no provisioner for it).

Consequences, both checked on the host:

| Behaviour | PowerShell 5.1 | PowerShell 7 |
|---|---|---|
| `$o = <native> 2>&1` with stderr output under `Stop` | **throws** (`RemoteException`) | does not throw |
| Captured stderr line type | `ErrorRecord` (prints as red `cmd : …` noise) | `ErrorRecord` |
| `0x8A15002B -eq -1978335189`; `'0x{0:X8}' -f -1978335212` → `0x8A150014` | True / OK | True / OK |

And under `iex` there is no script scope: `exit 1` terminates the user's interactive console, taking the error
message with it.

## Requirements

- **R0** `install.ps1` must work on Windows PowerShell 5.1 **and** PowerShell 7 (confirmed requirement). Nothing in
  the file may need PS 7: no `??`/`?.`, ternary, `&&`/`||` pipeline chains, `ForEach-Object -Parallel`, or reliance
  on 7-only native-command semantics. The 5.1 behaviour in the table above was measured on the host
  (5.1.26100); the VM run (Acceptance 2–3) confirms it on the real bootstrap path.
- **R1** Two helpers, `Invoke-Winget` and `Test-WingetNoProgress` (R3), are defined in `install.ps1`; `Invoke-Winget` wraps every winget call in the script (self-upgrade
  and the install loop). `install.ps1` is fetched alone with `irm`, so the helpers cannot live in a module or
  another file.
- **R2** The helper captures stdout and stderr (`2>&1`) and prints nothing on success. It sets
  `$ErrorActionPreference = 'Continue'` locally, so a stderr line cannot throw under an inherited `Stop` on 5.1, and
  it reads `$LASTEXITCODE` immediately after the call.
  It also sets `[Console]::OutputEncoding` to UTF-8 for the call and restores it in `finally`: winget writes UTF-8,
  and Windows PowerShell 5.1 decodes captured native output with the OEM code page (verified: `©` in
  `winget --help` arrives as `┬ę` under code page 852), which would garble exactly the failure log this issue is
  about (winget output is localized).
- **R3** `--no-progress` is added to the install parameters **only when the installed winget supports it**, so the
  captured output holds no spinner, progress bar or VT progress sequences (winget `doc/Settings.md`, *Visual →
  progressBar*: the flag takes precedence over the setting). The flag was added in winget **v1.29.70-preview**
  (release notes; PR #6049, stable from 1.29.240). The issue's plain "add it to `$params`" would make an older
  preinstalled winget reject every call with an unknown-argument error, so:
  `Test-WingetNoProgress` returns `$true` when `winget --version` (e.g. `v1.29.380`, `v1.29.70-preview`) parses to
  `>= 1.29.70` and `$false` otherwise, including when the call fails or the output does not parse. `install.ps1`
  appends `--no-progress` to `$params` after the self-upgrade step (which may have raised the version), and only
  if the function returns `$true`. The self-upgrade call itself runs without the flag.
- **R4** Success codes (decided; the rest are failures):

  | Code | winget name | Treated as |
  |---|---|---|
  | `0` | success | success |
  | `0x8A150061` | `PACKAGE_ALREADY_INSTALLED` | success (re-run on a provisioned machine) |
  | `0x8A15010D` | `INSTALL_ALREADY_INSTALLED` | success (another version installed) |
  | `0x8A15010E` | `INSTALL_DOWNGRADE` | success (a newer version installed) |
  | `0x8A15002B` | `UPDATE_NOT_APPLICABLE` | success (self-upgrade: nothing to do) |
  | `0x8A150109` | `INSTALL_REBOOT_REQUIRED_TO_FINISH` | success **with a warning** that a restart is needed; the files are in place and the bootstrap can continue |

  Codes are compared as signed `Int32` (PowerShell hex literals above `0x7FFFFFFF` are already negative).
- **R5** A failed **install** prints, with `Write-Host`: a line naming the package and the exit code as
  `0x{0:X8}` (e.g. `winget failed to install 'microsoft.dsc' (exit code 0x8A150014)`), then the captured output
  as plain strings (each element converted with `"$_"`, so `ErrorRecord`s do not print as red noise). Then it
  `throw`s. It never calls `exit`.
  - Under `iex (irm …)` the throw ends the script and leaves the user's console open with the message visible.
  - Under `powershell -File/-Command` the throw gives exit code 1; under `run-tests.ps1` (`Stop`) it aborts the run.
  - No log file: the output is shown directly.
- **R6** A failed **self-upgrade** prints `Write-Warning` with the exit code and the output, then the bootstrap
  continues. An outdated winget is not fatal.
- **R7** The self-upgrade query changes from `winget upgrade winget` to
  `winget upgrade --id Microsoft.AppInstaller --exact`. `winget search winget` matches `Microsoft.AppInstaller` by
  moniker but also unrelated packages by tag, and `winget show winget` reports *Multiple packages found*, so a bare
  query is ambiguous; with the new warning the ambiguity would surface as a false warning on every run. (Whether
  the old query already fails on a given machine depends on what is installed; not verified, since the upgrade
  must not run on the host.)
- **R8** Failures from missing administrator rights (`0x8A150019`, `COMMAND_REQUIRES_ADMIN`) get the generic R5
  message. The dedicated message and elevation belong to #37.

## Non-goals

- No change to the `winget` install branch (`Add-AppxPackage`), to the PATH refresh, or to `chezmoi init --apply`.
- No retries, no log file, no `$PSNativeCommandUseErrorActionPreference` (non-zero "already installed" codes must
  count as success; the explicit allowlist is the mechanism).
- No pins or update mechanisms (AGENTS.md: updating is winget's job).
- No handling of non-winget failures (`chezmoi init` errors, `Add-AppxPackage`).

## Acceptance

1. Unit tests (host, no winget, no install): the helper behaves per R2, R4–R6 under **both** `powershell.exe` 5.1
   and `pwsh`, including a stderr-writing fake `winget` under `$ErrorActionPreference = 'Stop'`.
   Command: see `docs/testing.md` ("Install script tests").
2. VM, success path: on a provisioned VM `run-tests.ps1 -BRANCH <branch>` prints only `► …` lines for the winget
   steps and passes (re-run covers `0x8A150061`).
3. VM, failure path: temporarily replacing one id with an unknown package makes the script stop with
   `winget failed to install '<id>' (exit code 0x8A150014)` and the winget output, without reaching `chezmoi`.
4. On a winget >= 1.29.70 the output shown in (3) contains no spinner characters and no garbled diacritics
   (localized message text intact).

The change closes #40 (`Fixes #40`). Per `docs/testing.md` the VM downloads `install.ps1` from GitHub, so the
branch must be pushed before steps 2–3.

## Risks

- The unit tests substitute a `winget.cmd` shim on `PATH`; they prove capture, exit-code handling and message
  format, not winget's real stdout/stderr split. Steps 2–3 in the VM are the only real proof.
- `0x8A150109` as success is a judgement call: if the pending restart later breaks the `pwsh` install, the warning
  is the only trace.
- #37 will add an elevation check ahead of the winget calls; keep `Invoke-Winget` free of any elevation logic so
  the two changes do not overlap.
