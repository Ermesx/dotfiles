# `install.ps1` winget Error Handling Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** `install.ps1` stays quiet when winget succeeds and stops, naming the package and the exit code and showing the suppressed output, when a required install fails.

**Architecture:** Two helpers (`Invoke-Winget`, `Test-WingetNoProgress`) are defined at the top of `install.ps1`; `Invoke-Winget` of `install.ps1`, captures `2>&1`, checks `$LASTEXITCODE` against an explicit success allowlist and either returns silently, warns (optional step) or prints and `throw`s (required step). It is tested by extracting its definition from `install.ps1` with the PowerShell parser and running it in child `powershell.exe` and `pwsh` processes against a `winget.cmd` shim, so neither host runs real winget.

**Tech Stack:** Windows PowerShell 5.1 (bootstrap host) and PowerShell 7, Pester 6.x.

**Spec:** [`docs/specs/install-winget-errors.md`](install-winget-errors.md)

## Global Constraints

- Branch: `docs/40-install-winget-errors` off `develop` (spec) — implementation continues on it or on `fix/40-install-winget-errors`; last commit carries `Fixes #40`. Conventional Commits with a scope, e.g. `fix(install): …`.
- `*.ps1` are **CRLF**, `*.md` are **LF**. After editing `install.ps1` verify with `git ls-files --eol install.ps1` (`w/crlf`).
- Never run `install.ps1`, `chezmoi apply` or real `winget install/upgrade` on the host. Tests use the shim only.
- Never `exit` in `install.ps1`; failures are `throw` (spec R5: `iex` has no script scope).
- `install.ps1` must stay a single self-contained file (fetched alone with `irm`).
- Success codes exactly as spec R4: `0`, `0x8A150061`, `0x8A15010D`, `0x8A15010E`, `0x8A15002B`; `0x8A150109` succeeds with a warning. Compared as signed `Int32`.
- Exit code printed as `'0x{0:X8}' -f $code`.
- Pester floor: `#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '6.0.0' }`.

## Review Focus

1. **`Stop` inherited under 5.1** — a stderr line from winget must not throw when the caller (`run-tests.ps1`) set `$ErrorActionPreference = 'Stop'`. Owned by Task 1 (`stderr under Stop, exit 0` on both hosts).
2. **Message readable on failure** — captured `ErrorRecord`s print as plain text, no `NativeCommandError` / `CategoryInfo` noise. Owned by Task 1.
3. **Re-run on a provisioned machine** — every "already installed / nothing to upgrade" code is silent success. Owned by Task 1 (one case per code).
4. **Bootstrap continues after an optional failure** — a failed self-upgrade warns and the next statement runs. Owned by Task 1 (`DONE` marker).
5. **Test must run in the VM too** — `execute-pester.ps1` runs everything under `tests/windows`, where `install.ps1` is not at `..\..\..`. Owned by Task 1 (path resolution, skip instead of fail).

## Test command

From the repo root (host):

```powershell
pwsh -NoProfile -Command 'Import-Module Pester -MinimumVersion 6.0.0; Invoke-Pester tests/windows/Install -Output Detailed'
```

---

### Task 1: `Invoke-Winget` helper with tests

**Files:**
- Modify: `install.ps1` (add the function above the `$params` block; do not call it yet)
- Create: `tests/windows/Install/Invoke-Winget.Tests.ps1`
- Modify: `docs/testing.md` (new section "Install script tests")

**Interfaces:**
- Consumes: nothing.
- Produces: `function Invoke-Winget { param([Parameter(Mandatory)][string[]]$Arguments, [Parameter(Mandatory)][string]$Package, [switch]$Optional) }` — `$Arguments` is the complete winget argument list (`'install', $id, <params>`); the verb for messages is `$Arguments[0]`. Returns nothing. Failure of a required call: prints R5 lines, then `throw`. Failure with `-Optional`: `Write-Warning` with code and output, returns. Also `function Test-WingetNoProgress { [OutputType([bool])] param() }` — `$true` iff `winget --version` parses to `>= 1.29.70` (strip leading `v` and any `-suffix`, parse with `[version]`); `$false` on non-zero exit or parse failure; never throws.

- [ ] **Step 1: Write the test harness** in `tests/windows/Install/Invoke-Winget.Tests.ps1`
  - `BeforeAll`: locate `install.ps1` via `$PSScriptRoot\..\..\..\install.ps1`, else `$HOME\.local\share\chezmoi\install.ps1` (VM synced folder); if neither exists, `Set-ItResult -Skipped` in each test (Review Focus 5). Extract the `Invoke-Winget` and `Test-WingetNoProgress` `FunctionDefinitionAst`s with `[System.Management.Automation.Language.Parser]::ParseFile` and keep their `Extent.Text` joined as `$script:helperText`. Create a temp dir containing `winget.cmd`: if the first argument is `--version`, `echo %FAKE_VERSION%` and `exit /b %FAKE_EXIT%`; otherwise echo `%FAKE_OUT%` to stdout if defined, `>&2 echo %FAKE_ERR%` to stderr if defined (no trailing space), then `exit /b %FAKE_EXIT%`.
  - Function `Invoke-InHost -Exe <'powershell.exe'|'pwsh'> -Call <string> -Exit <int> [-Out <string>] [-Err <string>] [-Version <string>]`: sets `FAKE_*` env vars and prepends the shim dir to `PATH` for the child only. It builds ONE script string (helper text, `$ErrorActionPreference='Stop'`, `$params=@()`, `<Call>`, `'DONE'`) and passes it with `-NoProfile -EncodedCommand <base64 UTF-16LE>` — no `. 'file'` dot-sourcing (blocked by a `Restricted` 5.1 execution policy) and no quoting through native argument passing. Returns `[pscustomobject]@{ ExitCode; Output = (stdout+stderr as one string); Lines = (Output split on newlines, each trimmed) }`.
  - Every `It` below uses `-ForEach @('powershell.exe','pwsh')` and the `Describe` is skipped per host if that exe is not on `PATH`.

- [ ] **Step 2: Write the failing tests** (names and assertions; each runs `Invoke-Winget -Package 'x.y' -Arguments (@('install','x.y') + $params)` unless noted)

  | `It` | Fake winget | Assert |
  |---|---|---|
  | `succeeds silently on exit 0` | exit 0, `FAKE_OUT='noisy log'` | `ExitCode -eq 0`; `Output.Trim() -eq 'DONE'` |
  | `treats <name> as success` for `0x8A150061`, `0x8A15010D`, `0x8A15010E`, `0x8A15002B` (pass the signed decimal in `FAKE_EXIT`) | that code, `FAKE_OUT='log'` | `ExitCode -eq 0`; `Output.Trim() -eq 'DONE'` |
  | `warns but continues on reboot required` | `-1978334967` (`0x8A150109`) | `ExitCode -eq 0`; `Output -match 'restart'`; `Output -match 'DONE'` |
  | `does not throw on stderr output under Stop` | exit 0, `FAKE_ERR='some stderr'` | `ExitCode -eq 0`; `Output.Trim() -eq 'DONE'` |
  | `fails with package, hex code and output` | `-1978335212` (`0x8A150014`), `FAKE_OUT='out line'`, `FAKE_ERR='err line'` | `ExitCode -eq 1`; `Output` matches `winget failed to install 'x.y' \(exit code 0x8A150014\)`; `Lines` contains an element equal to `out line` and one equal to `err line`; `Output` does **not** match `DONE` or `NativeCommandError` (do not assert on `CategoryInfo`: 5.1 prints it for the script's own `throw`) |
  | `restores the console encoding` | exit 0 | call prefixed with `$before = [Console]::OutputEncoding.CodePage` and followed by `"enc=$($before -eq [Console]::OutputEncoding.CodePage)"`; `Lines` contains `enc=True` |
  | `Test-WingetNoProgress` for `FAKE_VERSION` = `v1.29.380`, `v1.29.70-preview` (exit 0) | call `"supported=$(Test-WingetNoProgress)"` | `Lines` contains `supported=True` |
  | `Test-WingetNoProgress` for `v1.28.190` (exit 0), `garbage` (exit 0), `v1.29.380` with exit 1 | same | `Lines` contains `supported=False` |
  | `optional failure warns and continues` (call adds `-Optional`, `Arguments` starts with `'upgrade'`) | `-1978335212`, `FAKE_OUT='out line'` | `ExitCode -eq 0`; `Output` matches `WARNING.*upgrade.*0x8A150014`, contains `out line` and `DONE` |

- [ ] **Step 3: Run the tests; verify they fail**

  Run: the Test command above. Expected: all `It`s FAIL (`Invoke-Winget` is not defined / helper extraction returns nothing).

- [ ] **Step 4: Implement `Invoke-Winget` in `install.ps1`** per the Interfaces block. Approach: `$ErrorActionPreference = 'Continue'` as the first statement; save `[Console]::OutputEncoding`, set it to `[System.Text.Encoding]::UTF8` and restore it in `finally` (spec R2); `$output = winget @Arguments 2>&1`; `$code = $LASTEXITCODE` on the next line; `$ok` list holds the five success codes as signed Int32 literals; `0x8A150109` → `Write-Warning` mentioning a restart and returns; success returns. Output lines are rendered as `$output | ForEach-Object { "$_" }`. Required failure: `Write-Host` the R5 message and the lines, then `throw "Installing $Package failed (exit code $hex)"`. Keep the CRLF endings.

- [ ] **Step 5: Run the tests; verify they pass**

  Run: the Test command above. Expected: all PASS on both hosts.

- [ ] **Step 6: Mutation check** — temporarily remove the local `$ErrorActionPreference = 'Continue'`; Run: the Test command. Expected: `does not throw on stderr output under Stop` FAILS for `powershell.exe`. Restore the line.

- [ ] **Step 7: Document** — in `docs/testing.md` add "Install script tests": what they cover (helper only, shim, both hosts), the Test command, and that the real winget behaviour is only checked in the VM.

- [ ] **Step 8: Commit**

  ```bash
  git add install.ps1 tests/windows/Install/Invoke-Winget.Tests.ps1 docs/testing.md
  git commit -m "feat(install): add Invoke-Winget helper with tests"
  ```

### Task 2: Use the helper in the bootstrap

**Files:**
- Modify: `install.ps1` (`$params`, self-upgrade, install loop)
- Modify: `tests/windows/Install/Invoke-Winget.Tests.ps1` (script-shape tests)

**Interfaces:**
- Consumes: `Invoke-Winget -Arguments <string[]> -Package <string> [-Optional]` from Task 1.
- Produces: nothing.

- [ ] **Step 1: Write the failing script-shape tests** (parse `install.ps1` with the AST parser; host-independent, no child processes)
  - `adds --no-progress only behind Test-WingetNoProgress`: the string `--no-progress` appears in `install.ps1` exactly once, inside an `IfStatementAst` whose condition calls `Test-WingetNoProgress`, located after the self-upgrade `Invoke-Winget` call and before the install loop; it is not in the initial `$params` array.
  - `no winget call discards its output`: no pipeline in `install.ps1` contains both a `winget` command and `Out-Null`.
  - `self-upgrade is optional and targets Microsoft.AppInstaller`: an `Invoke-Winget` call has `-Optional` and an argument list containing `upgrade`, `--id`, `Microsoft.AppInstaller`, `--exact`.
  - `install loop uses the helper`: a call `Invoke-Winget … 'install' …` exists inside the `ForEach-Object` over `$wingets`.
  - `parses on Windows PowerShell 5.1`: run `powershell.exe -NoProfile -EncodedCommand` with a script that calls `[System.Management.Automation.Language.Parser]::ParseFile('<install.ps1>', [ref]$null, [ref]$errors)` and prints `errors=<count>`; assert `errors=0` (skip if `powershell.exe` is absent). Catches PS 7-only syntax (spec R0).
  - `script never calls exit`: no `ExitStatementAst` in the file.

- [ ] **Step 2: Run the tests; verify the five fail**

  Run: the Test command. Expected: 5 new FAILs, Task 1 tests still pass.

- [ ] **Step 3: Edit `install.ps1`**: after the winget `if/else` (self-upgrade or install) add `if (Test-WingetNoProgress) { $params += '--no-progress' }`; replace `winget upgrade winget @params| Out-Null` with `Invoke-Winget -Optional -Package 'Microsoft.AppInstaller' -Arguments (@('upgrade', '--id', 'Microsoft.AppInstaller', '--exact') + $params)`; replace the loop body's `winget install … | Out-Null` with `Invoke-Winget -Package $_ -Arguments (@('install', $_) + $params)`. Leave the `Write-Host '► …'` lines and everything after the loop untouched.

- [ ] **Step 4: Run the tests; verify all pass**, then `git ls-files --eol install.ps1` shows `w/crlf`, and `git diff --stat` touches only the files listed here.

- [ ] **Step 5: Commit** (push the branch afterwards: the VM downloads `install.ps1` from GitHub)

  ```bash
  git add install.ps1 tests/windows/Install/Invoke-Winget.Tests.ps1
  git commit -m "fix(install): stop on failed winget install and show output" -m "Fixes #40"
  ```

### Task 3: VM verification (manual, user-run)

**Files:** none (temporary local edit, not committed).

- [ ] **Step 1: Success path.** Push the branch. In the VM: `C:\vagrant\run-tests.ps1 -BRANCH <branch>` on a provisioned VM. Expected: winget steps print only `► …` lines; the suite passes (covers `0x8A150061`).
- [ ] **Step 2: Failure path.** Edit `$wingets` in the pushed `install.ps1` to include an unknown id (e.g. `nonexistent.package`), push, re-run. Expected: `winget failed to install 'nonexistent.package' (exit code 0x8A150014)`, the winget output below it, no `chezmoi` run. Revert the edit and push.
- [ ] **Step 3: Record the result** in the PR description (including which shell the VM run used, 5.1 or 7 — the spec could not determine it).

## Self-review

- Spec coverage: R1/R2/R4/R5/R6 → Task 1; R3/R7 and "no `exit`" → Task 2; R8 → covered by the generic failure test (no admin-specific code); Acceptance 1 → Tasks 1–2, 2–4 → Task 3.
- Types: `Invoke-Winget -Arguments/-Package/-Optional` and `Test-WingetNoProgress` are identical in both tasks and in the spec.
- Unverified until the VM: real localized winget output through the UTF-8 switch (the shim is ASCII), and which shell the VM run uses.
