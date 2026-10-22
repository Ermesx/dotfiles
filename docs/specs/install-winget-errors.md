# Spec: `install.ps1` stops on a failed winget install and shows why

Issue: [#40](https://github.com/Ermesx/dotfiles/issues/40) · Status: Draft · Date: 2026-10-22 ·
Plan: [`install-winget-errors.plan.md`](install-winget-errors.plan.md)

**User decision (2026-10-22):** the install script must stay as simple and readable as possible. No helper
functions and no test harness; the error handling is a few inline lines. This overrides the issue's suggested
`Invoke-Winget` helper.

## Problem

`install.ps1` runs `winget upgrade winget @params | Out-Null` and, in a loop, `winget install $_ @params | Out-Null`
for `twpayne.chezmoi`, `microsoft.dsc` and `microsoft.powershell`. The output is discarded and `$LASTEXITCODE` is
never read. A failed install (no rights, no network, source error) is invisible; the script goes on to
`chezmoi init --apply`, which fails later with an unrelated error when `dsc` or `pwsh` is missing.

The quiet output stays: on success the user sees only the `► …` progress lines.

## Execution context (verified 2026-10-22, host: Windows PowerShell 5.1.26100 and pwsh 7)

- The script is started with `iex (irm '…/install.ps1' | Out-String)` (`ReadMe.md`). On a fresh machine that is
  **Windows PowerShell 5.1**, because `microsoft.powershell` is installed by this very script. It must work on 5.1
  and on PowerShell 7 (R0).
- `tests/run-tests.ps1` runs the same line with `$ErrorActionPreference = "Stop"`, inherited by `install.ps1`.
- winget writes its messages (including "No package found…") to **stdout**. A plain `$out = winget …` therefore
  captures everything, with no `2>&1`. This avoids the 5.1 problem where `2>&1` on a native command turns stderr
  lines into `ErrorRecord`s that **throw** under `Stop` (checked: `cmd /c 'echo err 1>&2' 2>&1` throws on 5.1, not on
  7). Do not add `2>&1`.
- Under `iex` there is no script scope: `exit 1` terminates the user's console together with the message. Failures
  must `throw`.
- Hex literals above `0x7FFFFFFF` are signed `Int32` in both hosts (`0x8A15002B -eq -1978335189`), as is
  `$LASTEXITCODE`; `'0x{0:X8}' -f $LASTEXITCODE` prints `0x8A150014`.

## Requirements

- **R0** Works on Windows PowerShell 5.1 and PowerShell 7. No PS 7-only syntax (`??`, ternary, `&&`/`||`,
  `-Parallel`).
- **R1** No new functions. The handling is inline: one `$okCodes` array and one `if` after each winget call.
- **R2** Output is captured with `$out = winget …` (stdout only, see above) and printed only on failure.
- **R3** Success codes, compared with `-notin`; any other code is a failure:

  | Code | winget name | Why it is not a failure |
  |---|---|---|
  | `0` | success | |
  | `0x8A15002B` | `UPDATE_NOT_APPLICABLE` | self-upgrade: nothing to do |
  | `0x8A150061` | `PACKAGE_ALREADY_INSTALLED` | re-run on a provisioned machine |
  | `0x8A15010D` | `INSTALL_ALREADY_INSTALLED` | another version is installed |
  | `0x8A15010E` | `INSTALL_DOWNGRADE` | a newer version is installed |
  | `0x8A150109` | `INSTALL_REBOOT_REQUIRED_TO_FINISH` | files are in place; a restart is pending, the bootstrap can continue |

- **R4** A failed **install** writes the captured output with `Write-Host`, then `throw`s
  `winget failed to install '<id>' (exit code 0x8A150014)`. Never `exit`. Under `iex` the console stays open with the
  message visible; under `powershell -File/-Command` the exit code is 1; under `run-tests.ps1` (`Stop`) the run
  aborts. No log file.
- **R5** A failed **self-upgrade** is `Write-Warning` with the exit code and the output, and the bootstrap
  continues. An outdated winget is not fatal.
- **R6** The self-upgrade query becomes `winget upgrade --id Microsoft.AppInstaller --exact @params`.
  `winget search winget` matches `Microsoft.AppInstaller` by moniker but also unrelated packages by tag, and
  `winget show winget` answers *Multiple packages found*; with the new warning an ambiguous query would show up as a
  false warning on every run. (Not verified whether the old query already fails on a given machine; the upgrade must
  not run on the host.)
- **R7** `--no-progress` is appended to the **install** call only (`winget install $_ @params --no-progress`), so the
  output dumped on failure has no spinner or progress bar (winget `doc/Settings.md`, *Visual → progressBar*). The
  flag exists since winget v1.29.70-preview (release notes, PR #6049); the install loop runs after the self-upgrade.
  Decision for the owner: keep it (recommended: it only cleans the failure dump) or drop it for zero
  version-dependence.
- **R8** Missing administrator rights (`0x8A150019`) get the same generic R4 message. The dedicated message and
  elevation belong to #37.

## Non-goals

- No helper functions, no new files, no test harness (user decision above).
- No change to the winget install branch (`Add-AppxPackage`), the PATH refresh, or `chezmoi init --apply`.
- No retries, no log file, no `$PSNativeCommandUseErrorActionPreference` (the "already installed" codes are non-zero
  and must count as success; the explicit list is the mechanism).
- No pins or update mechanisms (AGENTS.md: updating is winget's job).

## Acceptance

1. `powershell.exe` 5.1 parses `install.ps1` with zero errors (R0); `git ls-files --eol install.ps1` shows
   `w/crlf`; the diff touches only `install.ps1`.
2. VM, success path: on a provisioned VM `run-tests.ps1 -BRANCH <branch>` prints only `► …` lines for the winget
   steps and passes (re-run covers `0x8A150061`).
3. VM, failure path: temporarily adding an unknown id to `$wingets` stops the script with
   `winget failed to install '<id>' (exit code 0x8A150014)` and winget's output, without reaching `chezmoi`.

The change closes #40 (`Fixes #40`). Per `docs/testing.md` the VM downloads `install.ps1` from GitHub, so the branch
must be pushed before steps 2–3. There are no automated tests: inline code in a script fetched with `irm` has no
seam, and adding one would bring back the helpers this spec rules out.

## Risks

- **Winget text encoding on 5.1.** 5.1 decodes captured native output with the OEM code page; winget writes UTF-8
  (checked: `©` arrives as `┬ę` under code page 852). Only the dumped winget text can lose diacritics; the line
  naming the package and the hex code is ASCII and stays intact. Accepted as a limitation to keep the script simple.
- **Old inbox winget and `--no-progress`.** If the self-upgrade fails on a machine whose preinstalled winget predates
  v1.29.70, every install fails with winget's unknown-argument error: loudly, but wrongly attributed. Dropping R7
  removes this.
- **`0x8A150109` as success** is a judgement call; if the pending restart later breaks the `pwsh` install, the exit
  code is the only trace.
- #37 will add an elevation check ahead of the winget calls; this change contains no elevation logic, so the two do
  not overlap.
