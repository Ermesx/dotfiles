# Write-Pretty Test Suite Fix Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make `tests/windows/Write-Pretty/Write-Pretty.Tests.ps1` pass on Pester 6.x without touching module code.

**Architecture:** Test-only change. Migrate mock assertions to `Should -Invoke`, fix the `Write-PrettyTable`
parameter filters (`$Object` is a `List[object]` for positional `Write-Host` calls), tighten them to exact rendered
lines, and contain the `$PSVersionTable` mutation. Document the local run command.

**Tech Stack:** PowerShell 7, Pester 6.x (verified on 6.2.0). Pester 5 and older are not supported.

**Spec:** [`docs/specs/write-pretty-tests.md`](write-pretty-tests.md)

## Global Constraints

- Branch: `fix/write-pretty-tests` off `develop`. Conventional Commits with a scope; last commit carries `Fixes #15`.
- `*.ps1` files are **CRLF**, `*.md` are **LF** (`.editorconfig` / `.gitattributes`); do not change line endings.
- No changes under `home/` — `Write-PrettyTable` is correct (spec, "Root cause").
- Never run `chezmoi apply` or `install.ps1` on the host. Tests below import the module from the working copy via
  `PSModulePath`; nothing is installed.
- Pester floor: `#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '6.0.0' }`. Do not add
  Pester 5 compatibility shims or run anything on Pester 5.

## Review Focus

1. **Hashtable column order** — `@{ Name; Age }` may render `Age` first. Owned by Task 2: hashtable asserts accept
   either order, but each alternative is an exact line (no `+`/`*` quantifiers that would hide padding bugs).
2. **Positional `Write-Host` binding** — any filter that type-checks `$Object` as `[string]` silently never matches.
   Owned by Task 2: all table filters compare `"$Object"`.
3. **`$PSVersionTable` leak** — a test leaving `PSVersion = 5.1.0` changes behaviour of later test files in the same
   run. Owned by Task 1: `AfterEach` restore.
4. **Empty / `$null` input** — `@() | Write-PrettyTable` must write nothing; `$null` rows must be skipped, not
   printed as blank rows. Owned by Task 2.
5. **Assertions that cannot fail** — the old filters passed "Should -Not -Throw" while asserting nothing useful.
   Owned by Task 2, Step 3: a deliberate mutation must turn a test red.

## Test command

Used by every task (from the worktree root):

```powershell
pwsh -NoProfile -Command 'Import-Module Pester -MinimumVersion 6.0.0; $env:PSModulePath = "$PWD\home\readonly_Documents\PowerShell\Modules;$env:PSModulePath"; Invoke-Pester tests/windows/Write-Pretty -Output Detailed'
```

Baseline before Task 1: `Tests Passed: 0, Failed: 8`.

---

### Task 1: Pester 6 compatibility and version-state hygiene

**Files:**
- Modify: `tests/windows/Write-Pretty/Write-Pretty.Tests.ps1:1-8` (header, `BeforeAll`), and every
  `Assert-MockCalled` line (lines 18, 31, 45, 59, 73, 92, 103, 114)

**Interfaces:**
- Consumes: nothing.
- Produces: `$script:originalPSVersion` captured in `BeforeAll`; Describe-level `AfterEach` restoring it. Task 2
  relies on this and does not set `PSVersion` itself.

- [ ] **Step 1: Confirm the failing baseline**

Run the test command.
Expected: `Tests Passed: 0, Failed: 8`, errors mention `Assert-MockCalled`.

- [ ] **Step 2: Replace the header and `BeforeAll`**

Replace lines 1–8 (from `#Requires` through the closing `}` of `BeforeAll`) with:

```powershell
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '6.0.0' }, Write-Pretty

Describe 'Write-Pretty' {

    BeforeAll {
        Import-Module Write-Pretty -Force
        # Tests fake the PowerShell version by mutating the session-wide $PSVersionTable
        $script:originalPSVersion = $PSVersionTable.PSVersion
    }

    AfterEach {
        $PSVersionTable.PSVersion = $script:originalPSVersion
    }
```

- [ ] **Step 3: Migrate every assertion**

In the whole file replace the token `Assert-MockCalled` with `Should -Invoke`. Parameters (`-Times`, `-Exactly`,
`-ParameterFilter`) are unchanged. Afterwards:

```powershell
Select-String -Path tests/windows/Write-Pretty/Write-Pretty.Tests.ps1 -Pattern 'Assert-MockCalled'
```

Expected: no output.

- [ ] **Step 4: Run the tests**

Run the test command.
Expected: `Tests Passed: 5, Failed: 3` — the three remaining failures are the `Write-PrettyTable`
cases with "called 0 times" (fixed in Task 2).

- [ ] **Step 5: Commit**

```powershell
git add tests/windows/Write-Pretty/Write-Pretty.Tests.ps1
git commit -m "test(write-pretty): migrate to Should -Invoke and restore PSVersion after each test"
```

---

### Task 2: Assert the rendered `Write-PrettyTable` output

**Files:**
- Modify: `tests/windows/Write-Pretty/Write-Pretty.Tests.ps1` — replace the whole
  `# New tests for Write-PrettyTable` comment and `Context 'Pipeline input for Write-PrettyTable' { … }` block

**Interfaces:**
- Consumes: Task 1's `AfterEach` (the table tests do not set `PSVersion`).
- Produces: nothing used later.

Rendering rules the expectations derive from (`Write-PrettyTable.ps1`): column width = max(header length, longest
value); separator = `+` + `-` × (width + 2) per column; row = `|` + ` value.PadRight(width) |` per column; output
order is separator, header (multiple `-NoNewline` pieces), separator, rows, separator — so the full separator line
is written **3 times**.

- [ ] **Step 1: Replace the context**

```powershell
        # Write-PrettyTable calls `Write-Host $line` positionally; Write-Host binds -Object with
        # ValueFromRemainingArguments, so $Object is a List[object], not a string. Compare "$Object".
        Context 'Write-PrettyTable' {
            It 'renders objects from the pipeline as a bordered table' {
                Mock Write-Host { }
                $data = @(
                    [pscustomobject]@{ Name = 'Alice'; Age = 30 },
                    [pscustomobject]@{ Name = 'Bob'; Age = 25 }
                )

                $data | Write-PrettyTable

                Should -Invoke Write-Host -Times 3 -Exactly -ParameterFilter { "$Object" -eq '+-------+-----+' }
                Should -Invoke Write-Host -Times 1 -Exactly -ParameterFilter { "$Object" -eq '| Alice | 30  |' }
                Should -Invoke Write-Host -Times 1 -Exactly -ParameterFilter { "$Object" -eq '| Bob   | 25  |' }
            }

            It 'renders an array passed as a single argument' {
                Mock Write-Host { }
                $data = @(
                    [pscustomobject]@{ Name = 'Carol'; Age = 40 },
                    [pscustomobject]@{ Name = 'Dave'; Age = 22 }
                )

                Write-PrettyTable -Data $data

                Should -Invoke Write-Host -Times 3 -Exactly -ParameterFilter { "$Object" -eq '+-------+-----+' }
                Should -Invoke Write-Host -Times 1 -Exactly -ParameterFilter { "$Object" -eq '| Carol | 40  |' }
                Should -Invoke Write-Host -Times 1 -Exactly -ParameterFilter { "$Object" -eq '| Dave  | 22  |' }
            }

            It 'renders hashtables from the pipeline' {
                Mock Write-Host { }
                $data = @(
                    @{ Name = 'Eve'; Age = 28 },
                    @{ Name = 'Frank'; Age = 33 }
                )

                $data | Write-PrettyTable

                # Hashtable key order is not guaranteed, so accept either column order
                Should -Invoke Write-Host -Times 3 -Exactly -ParameterFilter { "$Object" -match '^\+(-------\+-----|-----\+-------)\+$' }
                Should -Invoke Write-Host -Times 1 -Exactly -ParameterFilter { "$Object" -match '^\| (Eve   \| 28  |28  \| Eve   )\|$' }
                Should -Invoke Write-Host -Times 1 -Exactly -ParameterFilter { "$Object" -match '^\| (Frank \| 33  |33  \| Frank )\|$' }
            }

            It 'writes nothing for empty input' {
                Mock Write-Host { }

                @() | Write-PrettyTable

                Should -Invoke Write-Host -Times 0 -Exactly
            }

            It 'skips null rows' {
                Mock Write-Host { }

                Write-PrettyTable -Data @($null, [pscustomobject]@{ Name = 'Gina'; Age = 51 }, $null)

                Should -Invoke Write-Host -Times 1 -Exactly -ParameterFilter { "$Object" -eq '| Gina | 51  |' }
                Should -Invoke Write-Host -Times 3 -Exactly -ParameterFilter { "$Object" -eq '+------+-----+' }
            }
        }
```

Indentation: the `Context` sits at 8 spaces, inside `InModuleScope Write-Pretty { … }`, like the other contexts.

- [ ] **Step 2: Run the tests**

Run the test command.
Expected: `Tests Passed: 10, Failed: 0`.

- [ ] **Step 3: Prove the table tests can fail (mutation check, do not commit)**

In `home/readonly_Documents/PowerShell/Modules/Write-Pretty/public/Write-PrettyTable.ps1`, in the `end` block,
temporarily change `$sep += ('-' * ($colWidths[$col] + 2)) + '+'` to `$sep += ('-' * ($colWidths[$col] + 1)) + '+'`.
Run the test command.
Expected: `Tests Passed: 6, Failed: 4` — the four rendering tests fail; `writes nothing for empty input` and the
five `Write-Pretty` tests pass. If the hashtable test passes, its regexes are too loose. Then revert:

```powershell
git checkout -- home/readonly_Documents/PowerShell/Modules/Write-Pretty/public/Write-PrettyTable.ps1
git status --short   # only the test file is modified
```

- [ ] **Step 4: Commit**

```powershell
git add tests/windows/Write-Pretty/Write-Pretty.Tests.ps1
git commit -m "test(write-pretty): assert rendered Write-PrettyTable lines and edge cases"
```

---

### Task 3: Document running unit tests locally

**Files:**
- Modify: `docs/testing.md` (append a section)

**Interfaces:** none.

- [ ] **Step 1: Append to `docs/testing.md`**

````markdown

## Unit tests against the working copy

Module tests (currently `tests/windows/Write-Pretty/`) run on the host without applying chezmoi: prepend the
source module directory to `PSModulePath` in a child shell. Only Pester 6 is supported; the test files enforce it
with `#Requires`:

```powershell
pwsh -NoProfile -Command 'Import-Module Pester -MinimumVersion 6.0.0; $env:PSModulePath = "$PWD\home\readonly_Documents\PowerShell\Modules;$env:PSModulePath"; Invoke-Pester tests/windows/Write-Pretty -Output Detailed'
```

Without the `PSModulePath` prefix, `Import-Module Write-Pretty` loads the *installed* copy from `~/Documents`.
````

- [ ] **Step 2: Verify the documented command verbatim**

Copy the command from `docs/testing.md` and run it from the repo root.
Expected: `Tests Passed: 10, Failed: 0`.

- [ ] **Step 3: Commit**

```powershell
git add docs/testing.md
git commit -m "docs(testing): document running module unit tests against the working copy" -m "Fixes #15"
```
