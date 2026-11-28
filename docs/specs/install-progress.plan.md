# One Progress Look for Installers and Updaters Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The install scripts and the `Update-*` functions show finished items as one line each, the current item on one live line locally, and the tool's output only when an item fails.

**Architecture:** A new module `StepProgress` (one public function, `Invoke-ProgressSteps`) runs a list of items through an action, captures every stream per item, and draws either a live line plus permanent `✓` lines (interactive) or plain `✓` lines (CI). The `before_`/`after_` install scripts import it from the source tree through `$env:CHEZMOI_SOURCE_DIR`; `PackageUpdates` imports it from the deployed copy and its shared loop `Invoke-PackageUpdateLoop` delegates to it.

**Tech Stack:** PowerShell 7.6, Pester 6, chezmoi 2.73 templates.

**Spec:** [`docs/specs/install-progress.md`](install-progress.md) (decisions D1–D13, requirements R1–R18).

## Global Constraints

- Branch `feat/62-install-progress` (exists, merged with `origin/develop`). Conventional Commits with a scope (`feat(progress): …`, `refactor(packages): …`, `test(progress): …`, `docs: …`), each ending with `Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>`; the last commit also carries `Fixes #62`. Never push to `develop`, never force-push.
- `*.ps1`, `*.psm1`, `*.psd1`, `*.ps1.tmpl`: CRLF in the working tree (`.gitattributes`; check `git ls-files --eol <file>` → `w/crlf`). Everything else LF.
- Never run `chezmoi apply`, `install.ps1`, `scoop`, `Install-Module`, `Update-Module` or `dotnet tool` installs on the host. Host checks: Pester with mocks, template render + parse, grep. Always `chezmoi --source .` from the repo root.
- Module root: `home/readonly_Documents/PowerShell/Modules/StepProgress/` (called `<module>` below). Layout as `PackageUpdates`: `.psd1` with an explicit `FunctionsToExport`, `.psm1` that dot-sources `private/` and `public/` and exports the public functions, one function per file. **No `.tmpl` files in the module** and no dependency on `Write-Pretty` (neither exists yet on the first apply). Importing prints nothing.
- Tests: `tests/windows/StepProgress/`, first line `#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '6.0.0' }`. Test command (every task): `pwsh -NoProfile -Command 'Import-Module Pester -MinimumVersion 6.0.0; $env:PSModulePath = "$PWD\home\readonly_Documents\PowerShell\Modules;$env:PSModulePath"; Invoke-Pester tests/windows/StepProgress -Output Detailed'`. Static tests: `pwsh -NoProfile -Command 'Import-Module Pester -MinimumVersion 6.0.0; Invoke-Pester tests/static -Output Detailed'`.
- The module writes only with `Write-Host`; the success pipeline carries only the result object. Tests capture with `6>&1` (information records = lines, everything else = result).
- Copy fixed by the spec: header `► <title>` (cyan, live mode only); `✓ <name>  [<detail>]  <duration>`; `✗ <name>` (red, live mode only) followed by the item's output indented 4 spaces; summary `✓ N installed, M already present` / `✓ M already present` / `✓ N installed in <elapsed>` (`updated` for `-Verb Updated`); failure summary `✗ N failed: a, b`; no summary when exactly one item ran, succeeded and nothing was present. Plain mode: no ESC character at all.
- Failure of an item = its action throws, or `$LASTEXITCODE` is non-zero after it (the module sets `$global:LASTEXITCODE = 0` before each action). Callers add no exit-code checks.
- Install scripts: no `Get-Command` / exit-code guards (the packages are guaranteed by the dotfiles themselves); the module import goes **inside** each script's existing `{{ if }}` so an empty selection still renders an empty script; every script ends with `exit [int]($result.Failed.Count -gt 0)`.
- Code comments state the reason in words; they never cite issue, requirement or decision numbers.

## Review Focus

1. **Stale exit code:** item 1 fails with a native exit code, item 2 is pure PowerShell → item 2 must not be reported as failed (Task 1).
2. **An action that returns values or writes to the success pipeline** → the result stays one object, and the values never appear as lines (Task 1).
3. **Unknown or tiny terminal width** (`[Console]::WindowWidth` throws without a console; width below 20) → no exception, no wrapped live line (Task 2).
4. **Exception outside the action's own try** (a throwing `-Detail` block) while a live line is on screen → the line is cleared, no dangling `\r` (Task 2).
5. **`bucket/app` ids and case** (`nerd-fonts/Hasklig-NF` declared, `hasklig-nf` installed) → still recognised as present (Task 3).

---

### Task 1: Module `StepProgress` and plain mode

**Files:**
- Create: `<module>/StepProgress.psd1` (copy `PackageUpdates.psd1`; new GUID, `RootModule = 'StepProgress.psm1'`, `ModuleVersion = '1.0.0'`, `RequiredModules = @()`, `FunctionsToExport = @('Invoke-ProgressSteps')`), `<module>/StepProgress.psm1` (the `PackageUpdates.psm1` loader without its cache variables)
- Create: `<module>/public/Invoke-ProgressSteps.ps1`, `<module>/private/Format-Elapsed.ps1`, `<module>/private/Format-Summary.ps1`
- Test: `tests/windows/StepProgress/StepProgress.Tests.ps1`

**Interfaces:**
- Produces:
  - `Invoke-ProgressSteps -Title <string> -Items <object[]> -Action <scriptblock> [-Name <scriptblock>] [-Detail <scriptblock>] [-IsPresent <scriptblock>] [-Verb <'Installed'|'Updated'> = 'Installed'] [-Mode <'Auto'|'Live'|'Plain'> = 'Auto']` → `[pscustomobject]@{ Done = [int]; Present = [int]; Failed = [object[]] }`, each failed entry `@{ Item; Name; Output = [string] }`. `-Items` accepts an empty array (prints the header only). `-Name`, `-Detail`, `-IsPresent` and `-Action` are called with the item as their only argument (`param($item)`); `-Name` defaults to `"$item"`.
  - `Format-Elapsed -Span [timespan]` → `[string]`: under a minute `'6.1s'`, otherwise `'1m 12s'`.
  - `Format-Summary -Done [int] -Present [int] -Verb <'Installed'|'Updated'> -Elapsed [timespan]` → `[string]`, the three summary forms above, `''` when both counts are 0.

- [ ] **Step 1: Write the failing tests** in `StepProgress.Tests.ps1`. `BeforeAll` imports `StepProgress -Force` and defines `Invoke-Captured([scriptblock]$Script)` returning `@{ Lines; Result }` (`& $Script 6>&1`; `Lines` = `"$($_.MessageData)"` of every `[System.Management.Automation.InformationRecord]`, `Result` = everything else). All use `-Mode Plain`. Tests and their exact assertions:

| Test | Assertions |
|---|---|
| prints the title, then one `✓` line per item | `Lines[0] -eq '► Installing things'`; `Lines[1] -match '^✓ a +\d+\.\ds$'` (same for `b`) |
| counts the items it ran | `Result.Done -eq 2`, `Result.Present -eq 0`, last line `-match '^✓ 2 installed in \d'` |
| does not run or list present items | `-IsPresent { param($i) $i -ne 'b' }` over `a,b,c`: the action is called only for `b`; no line starts with `✓ a` or `✓ c`; `Result.Done -eq 1`, `Result.Present -eq 2`; last line `-eq '✓ 1 installed, 2 already present'` |
| importing prints nothing | `Import-Module StepProgress -Force 6>&1 4>&1 3>&1 \| Should -BeNullOrEmpty` |
| all present | `Done -eq 0`, `Present -eq 3`, action never called, last line `-eq '✓ 3 already present'` |
| single item that succeeded, nothing present | no line starts with `✓ 1 installed` |
| `-Verb Updated` | last line `-match '^✓ 2 updated in '`; `-Detail { '1.0 → 2.0' }` puts `1.0 → 2.0` on the item line |
| a throwing action fails the item and the run goes on | items `a,b,c`, `b` throws `'boom'`: `Lines` contain `'✗ b'` and a line `-eq '    boom'`; `c` still gets its `✓`; `Result.Failed.Name -eq 'b'`; last line `-eq '✗ 1 failed: b'` |
| a non-zero exit code fails the item, its output is shown | action: `Write-Host 'tool said no'; $global:LASTEXITCODE = 1` → `Result.Failed[0].Output -match 'tool said no'` and the output appears indented after `✗` |
| **stale exit code** | item `a` sets `$global:LASTEXITCODE = 1`, item `b` is `{ }` → `Result.Failed.Name -eq 'a'` only |
| output of a successful item is discarded | action `Write-Host 'chatter'` → no line matches `chatter` |
| **success pipeline values are not results** | action `{ 'x'; 42 }` → `@($Result).Count -eq 1` and no line matches `^(x|42)$` |
| empty items | only the header line; `Result.Done -eq 0` |
| plain mode has no control characters | every line `-notmatch '\x1b'` |
| `Format-Elapsed` / `Format-Summary` | `Format-Elapsed ([timespan]::FromSeconds(6.14)) -eq '6.1s'`, `(0) -eq '0.0s'`, `72.4 → '1m 12s'`; `Format-Summary -Done 0 -Present 0` is `''` (via `InModuleScope StepProgress`) |

- [ ] **Step 2: Run the test command; expect FAIL** (`The specified module 'StepProgress' was not loaded`).
- [ ] **Step 3: Create the module files and implement `Invoke-ProgressSteps` (plain mode only), `Format-Elapsed`, `Format-Summary`.** Per item: evaluate `-IsPresent` first and count present items without listing them; for the rest start a stopwatch, run `& $Action $item *>&1` inside `try`, collect the records as text with `Out-String`, append the exception message on a throw, then check `$LASTEXITCODE`; print the finished line and, on failure, the indented output. Names are padded to the longest name among the items that will run (at most 40 characters). `-Mode` is accepted now and ignored beyond `Plain` until Task 2.
- [ ] **Step 4: Run the test command; expect all PASS.**
- [ ] **Step 5: Commit**
  ```bash
  git add home/readonly_Documents/PowerShell/Modules/StepProgress tests/windows/StepProgress
  git commit -m "feat(progress): StepProgress module with plain-mode Invoke-ProgressSteps"
  ```

### Task 2: Live mode

**Files:**
- Modify: `<module>/public/Invoke-ProgressSteps.ps1`
- Create: `<module>/private/Resolve-ProgressMode.ps1`, `<module>/private/Format-LiveLine.ps1`, `<module>/private/Get-ProgressWidth.ps1`
- Test: `tests/windows/StepProgress/Live.Tests.ps1`

**Interfaces:**
- Consumes: Task 1's `Invoke-ProgressSteps` and the `Invoke-Captured` helper (repeat it in this file's `BeforeAll`).
- Produces:
  - `Resolve-ProgressMode -Mode <'Auto'|'Live'|'Plain'>` → `'Live'|'Plain'`; `Auto` is `Live` only when `$env:CI -ne 'true'` and `-not [Console]::IsOutputRedirected`.
  - `Get-ProgressWidth` → `[int]`: the window width, `80` when it cannot be read or is below 20.
  - `Format-LiveLine -Index <int> -Total <int> -Text <string> -Width <int> [-Ascii]` → `[string]`: a 24-cell bar with `floor(24 * (Index - 1) / Total)` filled cells (`█` / `░`; `#` / `-` with `-Ascii`), then `" $Index/$Total  $Text"`, cut to `Width - 1` characters with a trailing `…` (`~` with `-Ascii`).

- [ ] **Step 1: Write the failing tests:**

| Test | Assertions |
|---|---|
| `Resolve-ProgressMode` | `Plain` → `Plain`, `Live` → `Live`; `Auto` with `$env:CI = 'true'` → `Plain` (restore the variable in `AfterEach`) |
| `Format-LiveLine` bar | `-Index 3 -Total 4 -Text x -Width 80` → starts with `'█' * 12 + '░' * 12` and contains `' 3/4  x'`; `-Index 1` → 24 `░`; `-Ascii` → `'#' * 12 + '-' * 12` |
| `Format-LiveLine` truncation | `-Width 20` → `.Length -le 19` and ends with `…` |
| **`Get-ProgressWidth`** | returns an integer `-ge 20` and never throws (also with no console) |
| live line per item | with `-Mode Live`, over `a,b,c`: a record starting with `"`r`e[2K"` and containing `1/3` and `a` is written before `a` finishes; each finished line starts with `"`r`e[2K"` too |
| colours | `Mock Write-Host -ModuleName StepProgress` and assert: the header is written with `-ForegroundColor Cyan`, a `✗` line with `-ForegroundColor Red`, a `✓` line with neither |
| no dangling live line | after a normal run the last record is the summary, not a live line |
| **cleared on an unexpected exception** | `-Detail { param($i) if ($i -eq 'b') { throw 'detail broke' } }` with `-Mode Live` → the call throws and the last record is `"`r`e[2K"` |
| live mode summary | last line `-match '✓ 3 installed in'` without leading control characters |

- [ ] **Step 2: Run the test command (path `tests/windows/StepProgress`); expect FAIL** (missing functions).
- [ ] **Step 3: Implement the three private functions and the live branch.** Resolve the mode once at the start. In live mode, before each item runs write `"`r`e[2K" + (Format-LiveLine -Index <n> -Total <number of items to run> -Text "<installing|updating> <name>" -Width (Get-ProgressWidth))` with `-NoNewline`; the finished line is written as `"`r`e[2K" + <line>` so it replaces the live line; a `try/finally` writes `"`r`e[2K"` with `-NoNewline` if a live line is still showing. Colours (header cyan, `✗` red) use `Write-Host -ForegroundColor` and only in live mode. Use `-Ascii` when `[Console]::OutputEncoding.CodePage -ne 65001`.
- [ ] **Step 4: Run both test files; expect all PASS.**
- [ ] **Step 5: Commit** `feat(progress): live progress line for Invoke-ProgressSteps`

### Task 3: Install scripts

**Files:**
- Modify: `home/.chezmoiscripts/windows/run_onchange_before_01-scoop.ps1.tmpl`, `…/run_onchange_before_02-modules.ps1.tmpl`, `…/run_onchange_before_03-dotnet-tools.ps1.tmpl`, `…/run_once_after_yazi-plugins.ps1.tmpl`
- Test: `tests/static/InstallScripts.Tests.ps1`

**Interfaces:**
- Consumes: `Invoke-ProgressSteps` (Task 1; the scripts never pass `-Mode`).
- Produces: nothing for later tasks.

Each script renders its item list from the `packages.tmpl` view as a PowerShell array of single-quoted strings (`{{ . | squote }}`), imports the module first inside the existing `{{ if }}` with `Import-Module (Join-Path $env:CHEZMOI_SOURCE_DIR 'readonly_Documents/PowerShell/Modules/StepProgress/StepProgress.psd1')`, calls `Invoke-ProgressSteps`, and ends with `exit [int]($result.Failed.Count -gt 0)`. The part that differs per script:

| Script | Title | Presence (queried once, before the call) | Action per item |
|---|---|---|---|
| `01-scoop` (the bucket lines stay as they are) | `Installing Scoop apps` | `$installed = @(scoop list 6>$null \| ForEach-Object Name)`; `-IsPresent { param($app) ($app -split '/')[-1] -in $installed }` | `scoop install $app` |
| `02-modules` (keeps `Set-PSRepository`) | `Installing PowerShell modules` | `$installed = @(Get-InstalledModule -ErrorAction SilentlyContinue \| ForEach-Object Name)`; `$module -in $installed` | `Install-Module -Name $module -Scope CurrentUser -ErrorAction Stop`; for `Pester` add `-Force -SkipPublisherCheck` (keep the comment about the inbox Pester 3.4) |
| `03-dotnet-tools` (keeps the `PATH` / `DOTNET_ROOT` refresh at the top) | `Installing .NET tools` | `$installed = @((dotnet tool list -g --format json \| ConvertFrom-Json).data \| ForEach-Object packageId)`; `$tool -in $installed` | `dotnet tool install -g $tool` |
| `yazi-plugins` | `Installing yazi plugins` | the existing `$installedPlugins = ya pkg list`; `[bool]($installedPlugins -like "*$plugin*")` | `ya pkg add $plugin` |

- [ ] **Step 1: Update and add the static tests** in `InstallScripts.Tests.ps1`:
  - Replace the `^scoop install <app>$` assertions of *installs base and shell only* and *installs only picked apps* with `(?m)^\s*'<app>'\s*$` and `Should -Not -Match "'extras/rider'"`; keep the `Not -Match` for `dotnet-sdk` as `"'dotnet-sdk'"`. *installs modules and .NET tools of the selection* stays as it is.
  - New `Describe 'install scripts use StepProgress'`, for each of the four scripts rendered with the default data (`Get-RenderedScript <name>` without `-Data`: with no stored selection `packages.tmpl` selects every profile and pick, so every script is non-empty): contains the import line above, contains `Invoke-ProgressSteps`, ends with the `exit [int](...)` line, and the rendered text does not match `[A-Za-z]:[\\/]` (no absolute path in it).
  - The module folder contains no `*.tmpl`: `Get-ChildItem $root/home/readonly_Documents/PowerShell/Modules/StepProgress -Recurse -Filter *.tmpl | Should -BeNullOrEmpty`.
  - **Smoke:** with `$env:CHEZMOI_SOURCE_DIR = "$root/home"` the import line from the scripts loads the module (`Import-Module … -Force -PassThru` returns a module named `StepProgress`); restore the variable afterwards.
  - **Presence (Review Focus 5):** the predicate is inline in the template, so the static test only pins its text: the rendered 01 script contains `($app -split '/')[-1] -in $installed` (`-in` is case-insensitive). The behaviour itself (`nerd-fonts/Hasklig-NF` against an installed `hasklig-nf`) is checked on the VM in Task 5, step 6; it cannot run on the host, which has no Scoop.
- [ ] **Step 2: Run the static tests; expect FAIL** (old script content).
- [ ] **Step 3: Rewrite the four templates** as described above. Verify each renders and parses: `Get-Content -Raw home/.chezmoiscripts/windows/<script> | chezmoi --source . execute-template` piped to `[System.Management.Automation.Language.Parser]::ParseInput(…)` with no errors.
- [ ] **Step 4: Run the static tests; expect all PASS.**
- [ ] **Step 5: Commit** `refactor(packages): install scripts report through StepProgress`

### Task 4: `PackageUpdates` uses `StepProgress`

**Files:**
- Modify: `home/readonly_Documents/PowerShell/Modules/PackageUpdates/PackageUpdates.psd1` (`RequiredModules = @('Write-Pretty', 'StepProgress')`), `…/private/Invoke-PackageUpdateLoop.ps1`, `…/public/Update-Apps.ps1`, `…/public/Update-Modules.ps1`, `…/public/Update-DotnetTools.ps1`
- Test: `tests/windows/PackageUpdates/Update.Tests.ps1`

**Interfaces:**
- Consumes: `Invoke-ProgressSteps` (Task 1).
- Produces: `Invoke-PackageUpdateLoop -Rows <object[]> -Title <string> -Section <'Apps'|'Modules'|'DotnetTools'> -Update <scriptblock>` (the `-Kind` parameter goes away; `-Update` receives the item name and signals failure by throwing or a non-zero `$LASTEXITCODE`, no longer by returning `$false`). It still leaves only the failed rows in the cache section.

- [ ] **Step 1: Adapt `Update.Tests.ps1`.** Set `$env:CI = 'true'` in `BeforeAll` and restore it in `AfterAll` (plain output). Capture each `Update-*` call with `6>&1`. The behavioural tests keep their meaning (keep going after a failure; failed row stays in the cache; the list is computed after `scoop update`; nothing outdated updates nothing). Replace the message assertions: `Write-Red 'Failed to update app: jq'` → a line `'✗ jq'` in the captured lines; `'Failed to update module: PSfzf'` → `'✗ PSfzf'`; `'Failed to update .NET tool: refitter'` → `'✗ refitter'`; *shows why a module failed* → the captured lines contain `locked`. `Mock Write-Host` no longer sees the module's output; drop it and the `Write-Yellow` / `Write-Green` mocks that only served the old loop (keep `Write-Red` for the `Not updated: …` message of `Update-Apps`). New: a successful update prints `✓ git` with the detail `1.0 → 2.0`; the call to `scoop update` for Scoop and the buckets prints one `✓ Scoop and buckets` line and no summary.
- [ ] **Step 2: Run `Invoke-Pester tests/windows/PackageUpdates` (test command with that path); expect FAIL.**
- [ ] **Step 3: Implement.** `Invoke-PackageUpdateLoop` calls `Invoke-ProgressSteps -Title $Title -Items $Rows -Name { param($row) $row.Name } -Detail { param($row) "$($row.Old) → $($row.New)" } -Verb Updated -Action { param($row) & $Update $row.Name }` and writes the cache section from the failed items' rows. The `Update-*` blocks lose `Out-Host`, the `$LASTEXITCODE -eq 0` return and the `$global:LASTEXITCODE = 0` line: `Update-Apps` → `scoop update $name`; `Update-Modules` → `Update-Module … -ErrorAction Stop`; `Update-DotnetTools` → `dotnet tool update -g $name`. Titles: `Updating Apps`, `Updating Modules`, `Updating .NET tools`. `Update-Apps` runs its first step as `Invoke-ProgressSteps -Title 'Updating Scoop and buckets' -Items @('Scoop and buckets') -Verb Updated -Action { scoop update }` and keeps the second check and the `Not updated: …` message unchanged.
- [ ] **Step 4: Run the PackageUpdates and StepProgress tests; expect all PASS.**
- [ ] **Step 5: Commit** `refactor(updates): Update-* report through StepProgress`

### Task 5: CI, docs and final verification

**Files:**
- Modify: `.github/workflows/ci.yml` (the `Invoke-Pester -Path` of the unit-test step: add `tests/windows/StepProgress`), `docs/testing.md` (module tests list and command), `docs/chezmoi.md` or `docs/conventions.md` (whichever describes the install scripts: one paragraph on the module and why the scripts import it from `CHEZMOI_SOURCE_DIR`), `docs/architecture.md` (the line on the numbered scripts), `AGENTS.md` only if it lists modules

- [ ] **Step 1: Edit the files above.** `docs/testing.md`: `tests/windows/StepProgress/` next to the other module tests and in the command.
- [ ] **Step 2: Run the full host checks:** `Invoke-Pester tests/static, tests/windows/StepProgress, tests/windows/PackageUpdates, tests/windows/Write-Pretty, tests/windows/AdminSetup` (with the `PSModulePath` prefix); expect all PASS. Run `chezmoi --source . managed --include=scripts` and confirm the four scripts are still listed with the same names.
- [ ] **Step 3: Check the spec's acceptance criterion 5** with `chezmoi --source . execute-template` on the four scripts before and after a change to a module file (e.g. add a blank comment): the rendered output is byte-identical.
- [ ] **Step 4: Commit** `docs: StepProgress in the testing, chezmoi and architecture docs` and `ci: run the StepProgress tests`, the last one with `Fixes #62` in the body.
- [ ] **Step 5: Push and read the CI run** (`gh run watch`): the apply step shows one `✓` line per installed app, no tool output, and the unit-test step lists `StepProgress`. If `scoop bucket add` is noisy in that log, say so in the PR description instead of changing it here. This is also where the owner (or a temporary branch that is not part of the PR) makes one install item fail on purpose and confirms the CI log shows that item's full tool output and the step fails: the second half of acceptance 3.
- [ ] **Step 6 (VM, by the owner):** on the Vagrant VM run `C:\vagrant\run-tests.ps1 -BRANCH feat/62-install-progress`: first apply shows the live line and finished lines; a second `chezmoi apply` after adding one package shows `✓ 1 installed, N already present`; an app declared as `nerd-fonts/Hasklig-NF` is counted as present. `Update-Apps`, `Update-Modules`, `Update-DotnetTools` show the same look. Also look at: whether the .NET first-run banner pollutes the output of `dotnet tool list -g --format json` on a clean machine (if so, set `$env:DOTNET_NOLOGO = '1'` next to the PATH refresh in `03-dotnet-tools`); a narrow terminal window; Ctrl+C during an item (the live line is cleared); whether the bar is ASCII or Unicode on the first apply; and that Scoop's own download progress does not corrupt the live line.
