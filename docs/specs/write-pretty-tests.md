# Spec: Write-Pretty test suite passes on Pester 6

Issue: [#15](https://github.com/Ermesx/dotfiles/issues/15) · Status: Draft · Date: 2026-10-15 ·
Plan: [`write-pretty-tests.plan.md`](write-pretty-tests.plan.md)

## Problem

`tests/windows/Write-Pretty/Write-Pretty.Tests.ps1` fails against the working copy:

| Pester | Result | Failure |
|---|---|---|
| 5.7.1 | 5 / 8 pass | All three `Write-PrettyTable` cases: `Write-Host` "called 0 times" |
| 6.2.0 | 0 / 8 pass | `Assert-MockCalled` fails to load (`Should operator 'Be' is not registered`) |

`packages.windows.modules` installs `Pester` unpinned, so the VM gets the latest major (6.x) and the whole suite is
red there. **Pester 6 is the only supported version**; Pester 5 results are listed as diagnosis only and are not a
target.

## Root cause (verified 2026-10-15)

The issue's hypothesis — that `Write-PrettyTable` drifted from its tests after commit 2fdc319 — is **wrong**. The
function renders the expected table; the defects are in the tests.

1. **Wrong parameter filter.** `Write-PrettyTable` calls `Write-Host $sep` positionally. `Write-Host -Object` is
   declared with `ValueFromRemainingArguments`, so a positional argument binds as `List[object]`, not `string`.
   The filter `$Object -is [string] -and $Object -like '+*'` can never match. Observed types of `$Object` in the
   mock: `List[object]` for every positional call, `string` only for the `Write-Cyan` header cells (which go
   through `Write-Pretty` → `Write-Host @splat`).
2. **Removed API.** Pester 6 no longer ships a working `Assert-MockCalled`; the replacement is `Should -Invoke`.

Proof: replacing only those two things in a scratch copy gives 8 / 8 on Pester 6.2.0 with no change to
`Write-PrettyTable`.

## Requirements

- **R1** The suite passes on Pester 6.x (verified on 6.2.0), using the module from the working copy. Compatibility
  with Pester 5 or older is not maintained.
- **R2** No `Assert-MockCalled` remains; mock assertions use `Should -Invoke`.
- **R3** `Write-PrettyTable` tests assert the rendered lines (separator and data rows, exact text and count), not
  merely "some line starting with `+` was written". A table with wrong padding or a missing row must fail a test.
- **R4** Hashtable-input assertions must not depend on hashtable key order, which PowerShell does not guarantee,
  but must still match exact lines for each possible order.
- **R5** Edge cases are pinned: empty input writes nothing; `$null` elements are skipped.
- **R6** Tests that fake the PowerShell version by assigning `$PSVersionTable.PSVersion` restore the real value
  after each test, so the mutation cannot leak into other test files in the same `Invoke-Pester` run.
- **R7** The test file declares its Pester floor: `#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion =
  '6.0.0' }`, so running it under an older Pester (e.g. 3.4.0 that ships with Windows) fails fast instead of
  producing misleading results.
- **R8** `docs/testing.md` documents how to run the unit tests against the working copy without applying chezmoi.

## Non-goals

- No change to `Write-PrettyTable` or any other module code — it is correct.
- No pinning of Pester in `packages.yaml`; unpinned already resolves to the latest (6.x), and R7 guards the floor.
- No support for Pester 5 or older.
- No restructuring of `InModuleScope` usage (works on Pester 6; changing it is unrelated churn).
- No edits to `docs/known-issues.md` — it was already removed in f81a2af; the issue's last line is stale.

## Acceptance

```powershell
# from the repo root
pwsh -NoProfile -Command 'Import-Module Pester -MinimumVersion 6.0.0; $env:PSModulePath = "$PWD\home\readonly_Documents\PowerShell\Modules;$env:PSModulePath"; Invoke-Pester tests/windows/Write-Pretty -Output Detailed'
```

Reports `Tests Passed: 10, Failed: 0`. The change closes #15 (`Fixes #15`).

## Risks

- `$PSVersionTable.PSVersion` mutation is still the mechanism for testing the PS5 branch; it is fragile by nature
  (session-wide state). R6 contains it; replacing it with an injectable seam would mean changing module code, which
  is out of scope.
- The suite is unit-level but lives under `tests/windows/`, which the VM runner executes after a full install. It
  therefore also runs against the *installed* module in the VM, not just the working copy — same code, so expected
  to pass; confirmed only locally.
