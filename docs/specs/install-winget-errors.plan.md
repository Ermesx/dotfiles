# `install.ps1` winget Error Handling Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans (recommended for two tasks) or superpowers:subagent-driven-development to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** `install.ps1` stays quiet when winget installs succeed and stops with a readable message (what failed, why, exit code) when a required install fails.

**Architecture:** Inline only: a `$okCodes` array, a `$failReasons` hashtable and one `if` after the `winget install` call. The self-upgrade is untouched. No functions, no new files, no automated tests. The skill's TDD structure is set aside by explicit user decision (simplicity of the install script is the top requirement); verification is the host parse/line-ending check, a stand-in `winget` logic check and the VM run.

**Tech Stack:** Windows PowerShell 5.1 (bootstrap host) and PowerShell 7.

**Spec:** [`docs/specs/install-winget-errors.md`](install-winget-errors.md)

## Global Constraints

- Branch: `docs/40-install-winget-errors` (carries the spec; PR #41). Conventional Commits with a scope; the implementation commit carries `Fixes #40`.
- `install.ps1` is **CRLF**; verify with `git ls-files --eol install.ps1` → `w/crlf`.
- Never run `install.ps1`, `chezmoi apply` or a real `winget install/upgrade` on the host.
- No functions, no `exit`, no `2>&1`, no PS 7-only syntax (spec R0, R1, R4).
- The self-upgrade line stays exactly as it was (spec R5). Only `install.ps1` changes.

## Review Focus

1. **Re-run on a provisioned machine** — "already installed" codes must not stop the script (R3). Covered by Task 1 Step 3 and Task 2 Step 1.
2. **`throw`, not `exit`** — under `iex` an `exit` kills the console (R4). Covered by Task 1 Step 3 (grep) and Task 2 Step 2.
3. **PS 7-only syntax** — breaks the real bootstrap on 5.1 (R0). Covered by Task 1 Step 3 (5.1 parse).
4. **Unlisted exit code** — must still produce a message that tells the user what to do (R4 fallback). Covered by Task 1 Step 3.

---

### Task 1: Edit `install.ps1`

**Files:**
- Modify: `install.ps1` (below `$params`; leave the self-upgrade line, the winget `else` branch, the PATH refresh and `chezmoi init --apply` untouched)

**Interfaces:**
- Consumes: nothing.
- Produces: nothing (no functions).

- [ ] **Step 1: Add `$okCodes` and `$failReasons`** after the `$params` array, each with a one-line comment: `$okCodes = @(0, 0x8A150061, 0x8A15010D, 0x8A15010E, 0x8A150109)` and a hashtable `$failReasons` with the five code→reason pairs from spec R4 (reason texts verbatim).

- [ ] **Step 2: Rewrite the install loop body** (keep the `Write-Host "► Installing $_"` line): `winget install $_ @params --no-progress | Out-Null`, then `if ($LASTEXITCODE -notin $okCodes) { … }` that looks up `$reason = $failReasons[$LASTEXITCODE]`, falls back to `unexpected winget error, run 'winget install $_' to see the details`, and `throw`s `("Installing '{0}' failed: {1} (winget exit code 0x{2:X8})" -f $_, $reason, $LASTEXITCODE)`. Do not touch the self-upgrade line.

- [ ] **Step 3: Host checks** (nothing is installed; none of these run winget)
  - 5.1 parses: `powershell.exe -NoProfile -Command '$e=$null; [void][System.Management.Automation.Language.Parser]::ParseFile("install.ps1",[ref]$null,[ref]$e); "errors=" + @($e).Count'` → `errors=0`.
  - `git ls-files --eol install.ps1` → `w/crlf`; `git diff --stat` lists only `install.ps1`.
  - Grep `install.ps1` for `2>&1` and `function`: no matches. (`exit` appears only in the message text `winget exit code`.)
  - Logic check on `powershell.exe` and `pwsh`: run the script text up to `# Refresh PATH` (from `$params`, without the `param` block) with a stand-in `function winget { $global:LASTEXITCODE = <code> }` in a temp file under `.superpowers/`, under `$ErrorActionPreference = 'Stop'`. Codes `0` and `-1978335135` (`0x8A150061`) must reach the end; `-1978335212`, `-1978335207` and `1` must throw the R4 message with the matching reason (`1`: the fallback). Delete the temp file afterwards.

- [ ] **Step 4: Commit and push** (the VM downloads `install.ps1` from GitHub)

  ```bash
  git add install.ps1
  git commit -m "fix(install): stop on failed winget install with a clear message" -m "Fixes #40"
  git push
  ```

### Task 2: VM verification (manual, user-run)

**Files:** none (a temporary edit in Step 2 is reverted, not committed).

- [ ] **Step 1: Success path.** In the VM on a provisioned machine: `C:\vagrant\run-tests.ps1 -BRANCH docs/40-install-winget-errors`. Expected: the winget steps print only `► …` lines and the suite passes (re-run covers `0x8A150061`).
- [ ] **Step 2: Failure path.** Add an unknown id (e.g. `nonexistent.package`) to `$wingets` in the pushed `install.ps1`, re-run. Expected: `Installing 'nonexistent.package' failed: package not found in the winget sources (winget exit code 0x8A150014)` and no `chezmoi` run. Run once from `run-tests.ps1` and once from an interactive 5.1 console via `iex (irm …)`: the console must stay open with the message visible. Revert the edit and push.
- [ ] **Step 3: Record the result** in PR #41, including which shell the VM run used (5.1 or 7; not determinable from the repo).

## Self-review

- Spec coverage: R0 → Task 1 Step 3; R1–R4, R6 → Task 1 Steps 1–2; R5 → Task 1 Step 2 (untouched line) and Step 3 (diff); R7 → `$failReasons` entry; Acceptance 1–2 → Task 1 Step 3, 3–4 → Task 2.
- Unverified until the VM: real winget exit codes on a failing install, and the `iex` behaviour of `throw` in an interactive console.
