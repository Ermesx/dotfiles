# Spec: `install.ps1` stops on a failed winget install and says why

Issue: [#40](https://github.com/Ermesx/dotfiles/issues/40) · Status: Draft · Date: 2026-10-22 ·
Plan: [`install-winget-errors.plan.md`](install-winget-errors.plan.md)

**User decisions (2026-10-22):**
1. The install script must stay as simple and readable as possible. No helper functions and no test harness; the
   error handling is a few inline lines. This overrides the issue's suggested `Invoke-Winget` helper.
2. Error handling applies **only to the installation of the required tools**. The winget self-upgrade stays as it
   was (no check, output discarded).
3. A failure is reported with a **chosen message with context** (what failed and why), not by dumping winget's
   output. This overrides the issue's "print the captured output".

## Problem

`install.ps1` runs `winget install $_ @params | Out-Null` in a loop for `twpayne.chezmoi`, `microsoft.dsc` and
`microsoft.powershell`. The output is discarded and `$LASTEXITCODE` is never read. A failed install (no rights, no
network, source error) is invisible; the script goes on to `chezmoi init --apply`, which fails later with an
unrelated error when `dsc` or `pwsh` is missing.

The quiet output stays: on success the user sees only the `► …` progress lines.

## Execution context (verified 2026-10-22, host: Windows PowerShell 5.1.26100 and pwsh 7)

- The script is started with `iex (irm '…/install.ps1' | Out-String)` (`ReadMe.md`). On a fresh machine that is
  **Windows PowerShell 5.1**, because `microsoft.powershell` is installed by this very script. It must work on 5.1
  and on PowerShell 7 (R0).
- `tests/run-tests.ps1` runs the same line with `$ErrorActionPreference = "Stop"`, inherited by `install.ps1`.
- Under `iex` there is no script scope: `exit 1` terminates the user's console together with the message. Failures
  must `throw`.
- Hex literals above `0x7FFFFFFF` are signed `Int32` in both hosts (`0x8A15002B -eq -1978335189`), as is
  `$LASTEXITCODE`; `'0x{0:X8}' -f $LASTEXITCODE` prints `0x8A150014`. A hashtable keyed by such a literal is
  looked up correctly with `$LASTEXITCODE`.
- Because the output is not shown or captured, there is no `2>&1` (which on 5.1 turns native stderr into
  `ErrorRecord`s that throw under `Stop`) and no output-encoding concern.

## Requirements

- **R0** Works on Windows PowerShell 5.1 and PowerShell 7. No PS 7-only syntax (`??`, ternary, `&&`/`||`,
  `-Parallel`).
- **R1** No new functions. The handling is inline: one `$wingetCodes` hashtable (exit code → `$true` for a
  non-failure, or the text of the failure reason) and one `if` after the `winget install` call. A code absent from
  the table is a failure with the fallback reason (R4).
- **R2** The install call keeps discarding winget's output (`| Out-Null`); the exit code decides.
- **R3** Codes with the value `$true` are not failures; every other code is:

  | Code | winget name | Why it is not a failure |
  |---|---|---|
  | `0` | success | |
  | `0x8A150061` | `PACKAGE_ALREADY_INSTALLED` | re-run on a provisioned machine |
  | `0x8A15010D` | `INSTALL_ALREADY_INSTALLED` | another version is installed |
  | `0x8A15010E` | `INSTALL_DOWNGRADE` | a newer version is installed |
  | `0x8A150109` | `INSTALL_REBOOT_REQUIRED_TO_FINISH` | files are in place; a restart is pending, the bootstrap can continue |

- **R4** A failed install `throw`s one message of the form
  `Installing '<id>' failed: <reason> (winget exit code 0x<8 hex digits>)`; never `exit`. The `<reason>` is the text
  stored in `$wingetCodes` for the exit code:

  | Code | winget name | Reason in the message |
  |---|---|---|
  | `0x8A150014` | `NO_APPLICATIONS_FOUND` | package not found in the winget sources |
  | `0x8A150019` | `COMMAND_REQUIRES_ADMIN` | administrator rights are required, run the script from an elevated shell |
  | `0x8A150010` | `NO_APPLICABLE_INSTALLER` | no installer applicable to this system |
  | `0x8A150011` | `INSTALLER_HASH_MISMATCH` | installer hash does not match the manifest |
  | `0x8A15006D` | `SERVICE_UNAVAILABLE` | winget service is busy or unavailable, try again later |
  | any other | | `unexpected winget error, run 'winget install <id>' to see the details` |

  Under `iex` the console stays open with the message visible; under `powershell -File/-Command` the exit code is 1;
  under `run-tests.ps1` (`Stop`) the run aborts. No log file. The table is short on purpose: it lists the failures a
  bootstrap is most likely to meet; the fallback covers the rest.
- **R5** The winget self-upgrade is **unchanged**: `winget upgrade winget @params| Out-Null`, no exit-code check, no
  warning.
- **R6** `--no-progress` is appended to the install call (`winget install $_ @params --no-progress`), as decided by
  the owner. The flag exists since winget v1.29.70-preview (release notes, PR #6049). It no longer affects what the
  user sees (output is discarded), see Risks.
- **R7** Missing administrator rights (`0x8A150019`) get the message from the R4 table. Elevation itself belongs
  to #37.

## Non-goals

- No helper functions, no new files, no test harness (user decision 1).
- No error handling for the self-upgrade, the `Add-AppxPackage` branch, the PATH refresh or `chezmoi init --apply`.
- No dump of winget's output, no log file, no retries, no `$PSNativeCommandUseErrorActionPreference` (the
  "already installed" codes are non-zero and must count as success; the explicit list is the mechanism).
- No pins or update mechanisms (AGENTS.md: updating is winget's job).

## Acceptance

1. `powershell.exe` 5.1 parses `install.ps1` with zero errors (R0); `git ls-files --eol install.ps1` shows
   `w/crlf`; the diff touches only `install.ps1`.
2. Logic check on both hosts with a stand-in `winget` function that sets `$LASTEXITCODE` (no real winget): codes `0`
   and `0x8A150061` reach the end of the script; `0x8A150014`, `0x8A150019` and an unlisted code stop it with the
   R4 message.
3. VM, success path: on a provisioned VM `run-tests.ps1 -BRANCH <branch>` prints only `► …` lines for the winget
   steps and passes (re-run covers `0x8A150061`).
4. VM, failure path: temporarily adding an unknown id to `$wingets` stops the script with
   `Installing '<id>' failed: package not found in the winget sources (winget exit code 0x8A150014)`, without
   reaching `chezmoi`.

The change closes #40 (`Fixes #40`). Per `docs/testing.md` the VM downloads `install.ps1` from GitHub, so the branch
must be pushed before steps 3–4. There are no automated tests in the repo: inline code in a script fetched with
`irm` has no seam, and adding one would bring back the helpers this spec rules out.

## Risks

- **Unlisted failures give no detail.** Output is discarded, so a network or source failure with an unlisted code
  yields the fallback message and the user has to re-run `winget install <id>` by hand. Accepted in exchange for a
  short, readable script; extend `$failReasons` when a code turns out to be common.
- **`--no-progress` is now cosmetic.** Nothing shows winget's output, so the flag changes nothing visible. On a
  machine whose preinstalled winget predates v1.29.70 it makes every install fail with an unknown-argument error
  (reported through the fallback message). Dropping R6 removes the risk at no visible cost.
- **winget not on `PATH` right after its own installation.** In the `Add-AppxPackage` branch the PATH refresh runs
  only after the install loop, so `winget` may be missing from the current session; the call then fails without an
  exit code and the message ends in `exit code 0x` (observed). Pre-existing ordering, out of scope for #40.
- **`0x8A150109` as success** is a judgement call; if the pending restart later breaks the `pwsh` install, the exit
  code is the only trace.
- #37 will add an elevation check ahead of the winget calls; this change contains no elevation logic, so the two do
  not overlap.
