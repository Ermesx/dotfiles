# `install.ps1` winget Error Handling Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans (recommended for two tasks) or superpowers:subagent-driven-development to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** `install.ps1` stays quiet when winget succeeds and stops, naming the package and the exit code and showing winget's output, when a required install fails.

**Architecture:** Inline only: one `$okCodes` array and an `if` after each of the two winget calls. No functions, no new files, no automated tests. The skill's TDD structure is set aside by explicit user decision (simplicity of the install script is the top requirement); verification is the host parse/line-ending check plus the VM run.

**Tech Stack:** Windows PowerShell 5.1 (bootstrap host) and PowerShell 7.

**Spec:** [`docs/specs/install-winget-errors.md`](install-winget-errors.md)

## Global Constraints

- Branch: `docs/40-install-winget-errors` (already carries the spec; PR #41). Conventional Commits with a scope; the implementation commit carries `Fixes #40`.
- `install.ps1` is **CRLF**; verify with `git ls-files --eol install.ps1` → `w/crlf`.
- Never run `install.ps1`, `chezmoi apply` or a real `winget install/upgrade` on the host.
- No functions, no `exit`, no `2>&1`, no PS 7-only syntax (spec R0, R1, R2, R4).
- Only `install.ps1` changes.

## Review Focus

1. **Re-run on a provisioned machine** — "already installed / nothing to upgrade" codes must not stop the script (R3). Covered by Task 2 Step 1.
2. **`throw`, not `exit`** — under `iex` an `exit` kills the console (R4). Covered by Task 1 Step 3 (grep) and Task 2 Step 2.
3. **PS 7-only syntax** — breaks the real bootstrap on 5.1 (R0). Covered by Task 1 Step 3 (5.1 parse).
4. **Failure that never reaches the user** — the message must be visible after `throw` under `iex` in a 5.1 console. Covered by Task 2 Step 2.

---

### Task 1: Edit `install.ps1`

**Files:**
- Modify: `install.ps1` (`$params` block and below; leave the winget `else` branch, the PATH refresh and `chezmoi init --apply` untouched)

**Interfaces:**
- Consumes: nothing.
- Produces: nothing (no functions).

- [ ] **Step 1: Add `$okCodes`** after the `$params` array, with a one-line comment naming what the codes mean (ok, nothing to upgrade, already installed, newer installed, reboot pending): `$okCodes = @(0, 0x8A15002B, 0x8A150061, 0x8A15010D, 0x8A15010E, 0x8A150109)`.

- [ ] **Step 2: Rewrite the two winget calls** (spec R2–R7):
  - Self-upgrade: `$out = winget upgrade --id Microsoft.AppInstaller --exact @params`, then `if ($LASTEXITCODE -notin $okCodes) { Write-Warning ("winget self-upgrade failed (exit code 0x{0:X8})`n{1}" -f $LASTEXITCODE, ($out -join "`n")) }`.
  - Install loop (keep the `Write-Host "► Installing $_"` line): `$out = winget install $_ @params --no-progress`, then `if ($LASTEXITCODE -notin $okCodes) { $out | Write-Host; throw ("winget failed to install '{0}' (exit code 0x{1:X8})" -f $_, $LASTEXITCODE) }`.
  - Remove both `| Out-Null`.

- [ ] **Step 3: Host checks** (nothing is installed; none of these run winget)
  - 5.1 parses: `powershell.exe -NoProfile -Command "[void][System.Management.Automation.Language.Parser]::ParseFile('install.ps1',[ref]$null,[ref]($e=$null)); 'errors=' + @($e).Count"` → `errors=0`.
  - `git ls-files --eol install.ps1` → `w/crlf`.
  - `git diff --stat` lists only `install.ps1`.
  - Grep `install.ps1` for `exit`, `2>&1`, `Out-Null`, `function`: no matches.

- [ ] **Step 4: Commit and push** (the VM downloads `install.ps1` from GitHub)

  ```bash
  git add install.ps1
  git commit -m "fix(install): stop on failed winget install and show output" -m "Fixes #40"
  git push
  ```

### Task 2: VM verification (manual, user-run)

**Files:** none (a temporary edit in Step 2 is reverted, not committed).

- [ ] **Step 1: Success path.** In the VM on a provisioned machine: `C:\vagrant\run-tests.ps1 -BRANCH docs/40-install-winget-errors`. Expected: the winget steps print only `► …` lines and the suite passes (re-run covers `0x8A150061`).
- [ ] **Step 2: Failure path.** Add an unknown id (e.g. `nonexistent.package`) to `$wingets` in the pushed `install.ps1`, re-run. Expected: `winget failed to install 'nonexistent.package' (exit code 0x8A150014)` preceded by winget's output, and no `chezmoi` run. Run once from `run-tests.ps1` and once from an interactive 5.1 console via `iex (irm …)`: the console must stay open with the message visible. Revert the edit and push.
- [ ] **Step 3: Record the result** in PR #41, including which shell the VM run used (5.1 or 7; not determinable from the repo).

## Self-review

- Spec coverage: R0 → Task 1 Step 3; R1–R7 → Task 1 Steps 1–2; R8 → no code (generic message); Acceptance 1 → Task 1 Step 3, 2–3 → Task 2.
- Unverified until the VM: real winget failure output on 5.1 (localized text, encoding), and the `iex` behaviour of `throw` in an interactive console.
