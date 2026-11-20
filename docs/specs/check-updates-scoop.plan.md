# Check-Updates on Scoop Implementation Plan

> **Superseded in part (2026-11-21).** This is the original execution plan. Review findings changed the design: `Update-Apps` checks the state again after the loop (R9), update output goes to the host (R9a), every installed .NET tool is checked and `DotnetTools` is no longer declared (D6), the refresh takes an exclusive lock file and isolates each check (R7). The requirements marked **[added]** / **[revised]** in [`check-updates-scoop.md`](check-updates-scoop.md) are authoritative.

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** `Check-Updates` / `Update-*` report and update declared Scoop apps, PowerShell modules and .NET global tools, refreshed in the background without blocking the prompt.

**Architecture:** A new module `PackageUpdates` (same layout as `Write-Pretty`) holds the checks, the shared cache and the user commands; every function takes the declared lists as `-Declared`. The profile fragment `check-updates.ps1.tmpl` only renders those lists into `$Global:PackageUpdatesDeclared` and registers a 30-minute timer that starts a thread job when the cache is older than 4 hours.

**Tech Stack:** PowerShell 7.6 (`Microsoft.PowerShell.ThreadJob`), Scoop v0.6.0 (`scoop status --local` objects), .NET SDK 10 (`dotnet tool list -g --format json`), NuGet flat container API, PowerShellGet 2.2.5, chezmoi templates (sprig), Pester 6.

**Spec:** [`docs/specs/check-updates-scoop.md`](check-updates-scoop.md) (decisions D1–D5, requirements R1–R15).

## Global Constraints

- Branch `feat/45-check-updates-scoop` off `develop`. Conventional Commits with a scope (`feat(profile): …`, `test(profile): …`, `docs: …`); the last commit carries `Fixes #45`.
- `*.ps1`, `*.psm1`, `*.psd1`, `*.ps1.tmpl`: CRLF in the working tree (`.gitattributes` normalises; check `git ls-files --eol <file>` → `w/crlf`). Everything else LF.
- Never run `chezmoi apply`, `install.ps1`, `scoop`, `Update-Module` or `dotnet tool update` on the host. Host checks: Pester with mocks, template render + parse, grep.
- Always `chezmoi --source .` from the repo root.
- Module root: `home/readonly_Documents/PowerShell/Modules/PackageUpdates/`. Tests: `tests/windows/PackageUpdates/`, first line `#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '6.0.0' }`.
- Test command (every task): `pwsh -NoProfile -Command 'Import-Module Pester -MinimumVersion 6.0.0; $env:PSModulePath = "$PWD\home\readonly_Documents\PowerShell\Modules;$env:PSModulePath"; Invoke-Pester tests/windows/PackageUpdates -Output Detailed'`.
- Tests mock external commands with `-ModuleName PackageUpdates`. `scoop` is not on the host: define `function global:scoop {}` in `BeforeAll` before mocking it, remove it in `AfterAll`. Mocks that emulate a failure set `$global:LASTEXITCODE = 1`.
- Cache path is the module variable `$script:CacheFile` (default `Join-Path $env:TEMP 'PackageUpdatesCache.json'`); tests set it to a `TestDrive:` path inside `InModuleScope`.
- Row shape everywhere: `[pscustomobject]@{ Name; Old; New }`. Name comparisons case-insensitive (`-contains`, `-in`).
- Copy fixed by the spec: headers `__APPS__`, `__MODULES__`, `__DOTNET TOOLS__`; `Last checked: <lastRun>`; `No update data yet. Run Check-Updates -Now.`; `► Updating Scoop and buckets`; ` - Updating <Name> [<Old> => <New>]`; `Failed to update app: <Name>`, `Failed to update module: <Name>`, `Failed to update .NET tool: <Name>`.
- No winget reference in the module or the fragment.

## Review Focus

1. **Corrupt or empty cache file** (killed refresh, half-written JSON) → `Check-Updates` prints the "no data" line, `Test-PackageUpdatesCacheStale` returns `$true`; never throws. Test in Task 1.
2. **Scoop output that is not a status row** (strings from an older Scoop, rows with empty `Latest Version` for failed/deprecated apps, held apps) → ignored. Tests in Task 2.
3. **Declared name in a different case than Scoop's app dir** (`Hasklig-NF` vs `hasklig-nf`) → still matched. Test in Task 2.
4. **NuGet unreachable for one tool** → the other tools are still reported. Test in Task 2.
5. **A failed update in the middle of the list** → later items still updated, and the cache keeps only the failed one. Tests in Task 4.

---

### Task 1: Module skeleton and cache

**Files:**
- Create: `home/readonly_Documents/PowerShell/Modules/PackageUpdates/PackageUpdates.psd1` (copy of `Write-Pretty.psd1` with new `RootModule`, `ModuleVersion = '1.0.0'`, new GUID, `RequiredModules = @('Write-Pretty')`)
- Create: `…/PackageUpdates/PackageUpdates.psm1` (same loader as `Write-Pretty.psm1`, plus `$script:CacheFile` and `$script:MaxCacheAge = [TimeSpan]::FromHours(4)` defined before dot-sourcing)
- Create: `…/PackageUpdates/private/Read-PackageUpdatesCache.ps1`, `…/private/Write-PackageUpdatesCache.ps1`, `…/public/Test-PackageUpdatesCacheStale.ps1`
- Test: `tests/windows/PackageUpdates/Cache.Tests.ps1`

**Interfaces:**
- Produces: `Read-PackageUpdatesCache` → `[pscustomobject]@{ LastRun = [datetime] or $null; Apps = @(); Modules = @(); DotnetTools = @() }` (arrays of rows). `Write-PackageUpdatesCache -Cache <that object>` writes JSON `{ lastRun (ISO 8601 'o'), apps, modules, dotnetTools }`. `Test-PackageUpdatesCacheStale` → `[bool]`.

- [ ] **Step 1: Write `Cache.Tests.ps1`** (`InModuleScope PackageUpdates`, `$script:CacheFile` = `TestDrive:\cache.json`):
  - `Read-PackageUpdatesCache` with no file → `LastRun` is `$null`, `Apps.Count`, `Modules.Count`, `DotnetTools.Count` are `0`.
  - same for an empty file and for `'{ not json'` (no exception).
  - round trip: write `LastRun = [datetime]'2026-11-20T10:00:00'`, `Apps = @([pscustomobject]@{Name='git';Old='2.50';New='2.51'})` → read back `LastRun` equals it, `Apps[0].Name` is `git`, `Apps[0].New` is `2.51`; a single row comes back as an array (`@($c.Apps).Count -eq 1`).
  - `Test-PackageUpdatesCacheStale`: no file → `$true`; `LastRun` = now − 5 h → `$true`; now − 1 h → `$false`; corrupt file → `$true`.
- [ ] **Step 2: Run the test command, expect FAIL** (module not found).
- [ ] **Step 3: Create the files.** Read: `Get-Content -Raw` + `ConvertFrom-Json` in `try/catch`, any failure or `$null` → the empty object; wrap sections with `@(...)`. Write: `ConvertTo-Json -Depth 5` with `-AsArray`-safe sections (`@()`), `Set-Content -Encoding UTF8`.
- [ ] **Step 4: Run the test command, expect PASS.**
- [ ] **Step 5: Commit** `feat(profile): PackageUpdates module with a shared update cache`.

### Task 2: The three checks

**Files:**
- Create: `…/PackageUpdates/private/Get-ScoopAppUpdates.ps1`, `…/private/Get-ModuleUpdates.ps1`, `…/private/Get-DotnetToolUpdates.ps1`, `…/private/Get-NuGetLatestStableVersion.ps1`
- Test: `tests/windows/PackageUpdates/Checks.Tests.ps1`

**Interfaces:**
- Consumes: nothing from Task 1.
- Produces: `Get-ScoopAppUpdates -Names [string[]]`, `Get-ModuleUpdates -Names [string[]]`, `Get-DotnetToolUpdates -Ids [string[]]` → rows; `Get-NuGetLatestStableVersion -Id [string]` → `[version]` or `$null`.

- [ ] **Step 1: Write `Checks.Tests.ps1`** (`InModuleScope PackageUpdates`). Scoop status rows are built as `[pscustomobject]@{ Name=…; 'Installed Version'=…; 'Latest Version'=…; 'Missing Dependencies'=''; Info=… }`.
  - `Get-ScoopAppUpdates -Names git,Hasklig-NF,jq` with `scoop` returning: `git` 2.50→2.51; `hasklig-nf` 3.3→3.4; `jq` held (`Info='Held package'`, 1.7→1.8); `fzf` 0.60→0.61 (undeclared); `bat` failed (`'Latest Version'=''`, `Info='Install failed'`); the string `'Scoop is up to date.'` → result names exactly `git`, `hasklig-nf`; `git` row `Old='2.50'`, `New='2.51'`.
  - `Should -Invoke scoop -ParameterFilter { $args -contains 'status' -and $args -contains '--local' }`.
  - `Get-ModuleUpdates -Names PSfzf,posh-git,Pester`: `Get-InstalledModule` → PSfzf 2.6.0, posh-git 1.1.0, Pester not installed (throws); `Find-Module` → PSfzf 2.7.0, posh-git 1.1.0 → one row `PSfzf` `2.6.0`→`2.7.0`; `Find-Module` invoked for `PSfzf` and `posh-git` only, never for an undeclared module.
  - `Get-NuGetLatestStableVersion -Id Dotnet-EF` with `Invoke-RestMethod` returning `@{ versions = @('9.0.10','10.0.0','10.0.1-preview.1') }` → `[version]'10.0.0'`; invoked with URI `https://api.nuget.org/v3-flatcontainer/dotnet-ef/index.json`; `Invoke-RestMethod` throws → `$null`.
  - `Get-DotnetToolUpdates -Ids dotnet-ef,refitter,dotnet-trace`: `dotnet` returns `'{"version":1,"data":[{"packageId":"dotnet-ef","version":"9.0.10"},{"packageId":"refitter","version":"1.6.5"},{"packageId":"upgrade-assistant","version":"1.0.518"}]}'`; latest: dotnet-ef 10.0.0, refitter → `$null` (NuGet failed) → one row `dotnet-ef` `9.0.10`→`10.0.0`; `upgrade-assistant` and the not-installed `dotnet-trace` are not queried.
- [ ] **Step 2: Run the test command, expect FAIL.**
- [ ] **Step 3: Implement.** Scoop: `scoop status --local 6>$null`, keep `$_.PSObject.Properties['Latest Version']` with a non-empty value, `Info -notmatch 'Held package'`, `Name -in $Names`. Modules: per name, `Get-InstalledModule -Name $n -ErrorAction Stop` and `Find-Module -Name $n -ErrorAction Stop` in `try/catch` (skip on error), compare `[version]`. .NET: `dotnet tool list -g --format json | ConvertFrom-Json`, filter `packageId -in $Ids`, compare `[version]`.
- [ ] **Step 4: Run the test command, expect PASS.**
- [ ] **Step 5: Commit** `feat(profile): check Scoop apps, modules and .NET tools for updates`.

### Task 3: Refresh and `Check-Updates`

**Files:**
- Create: `…/PackageUpdates/public/Update-PackageUpdatesCache.ps1`, `…/public/Check-Updates.ps1`
- Test: `tests/windows/PackageUpdates/CheckUpdates.Tests.ps1`

**Interfaces:**
- Consumes: Task 1 cache functions; Task 2 checks.
- Produces: `Update-PackageUpdatesCache [-Declared hashtable]`; `Check-Updates [-Now] [-Declared hashtable]`. `-Declared` defaults to `$Global:PackageUpdatesDeclared` with keys `Apps`, `Modules`, `DotnetTools`.

- [ ] **Step 1: Write `CheckUpdates.Tests.ps1`** (`InModuleScope PackageUpdates`, cache in `TestDrive:`, `Write-Green`, `Write-PrettyTable`, `Write-Host` mocked, `$d = @{ Apps=@('git'); Modules=@('PSfzf'); DotnetTools=@('dotnet-ef') }`, checks mocked to return one row each):
  - `Update-PackageUpdatesCache -Declared $d` → `scoop` invoked with `update` before `Get-ScoopAppUpdates`; each check invoked with its list (`-Names`/`-Ids` equal to `$d` values); the cache read back has one row per section and `LastRun` within the last minute.
  - claim: a `Write-PackageUpdatesCache` call happens **before** `scoop update` (mock `scoop` to read the cache file and assert `LastRun` is already fresh).
  - `scoop update` failing (`LASTEXITCODE=1`) → the three checks are still invoked.
  - `Check-Updates` (no `-Now`) with a cache holding one app row → `Write-Green` invoked with `__APPS__`, `Write-PrettyTable` invoked once, `Write-Host` invoked with a string matching `^Last checked: `; checks not invoked.
  - `Check-Updates` with no cache → `Write-Host` with `No update data yet. Run Check-Updates -Now.`; `Write-PrettyTable` not invoked.
  - `Check-Updates -Now -Declared $d` → `Update-PackageUpdatesCache` path runs (checks invoked) and `__DOTNET TOOLS__` is printed.
- [ ] **Step 2: Run the test command, expect FAIL.**
- [ ] **Step 3: Implement.** Refresh: read cache, set `LastRun = Get-Date`, write (claim); `scoop update *>$null` in `try/catch`; run the three checks; write. `Check-Updates`: `-Now` → refresh, then read; print sections in the order apps, modules, .NET tools.
- [ ] **Step 4: Run the test command, expect PASS.**
- [ ] **Step 5: Commit** `feat(profile): background-safe refresh and Check-Updates on the new cache`.

### Task 4: `Update-Apps`, `Update-Modules`, `Update-DotnetTools`

**Files:**
- Create: `…/PackageUpdates/public/Update-Apps.ps1`, `…/public/Update-Modules.ps1`, `…/public/Update-DotnetTools.ps1`
- Test: `tests/windows/PackageUpdates/Update.Tests.ps1`

**Interfaces:**
- Consumes: Task 1 cache functions, Task 2 checks.
- Produces: `Update-Apps`, `Update-Modules`, `Update-DotnetTools`, each `[-Declared hashtable]`, no output objects.

- [ ] **Step 1: Write `Update.Tests.ps1`** (`InModuleScope PackageUpdates`, `Write-*` helpers mocked, cache pre-filled with `LastRun` = a fixed date and one row in every section):
  - `Update-Apps`: `Get-ScoopAppUpdates` → `git`, `jq`, `bat`; `scoop` mock sets `LASTEXITCODE=1` for `jq` and `0` otherwise → `scoop` invoked with `update` alone first, then `update git`, `update jq`, `update bat` (all three, in order); `Write-Red` invoked once with `Failed to update app: jq`; the cache `Apps` is exactly `jq`; `LastRun`, `Modules`, `DotnetTools` unchanged.
  - `Update-Apps` with no rows → no per-app `scoop update <name>` call, cache `Apps` empty.
  - `Update-Modules`: `Get-ModuleUpdates` → `PSfzf`, `posh-git`; `Update-Module` throws for `PSfzf` → `Update-Module` invoked for both with `Scope -eq 'CurrentUser'`; `Write-Red` with `Failed to update module: PSfzf`; cache `Modules` is exactly `PSfzf`.
  - `Update-DotnetTools`: `Get-DotnetToolUpdates` → `dotnet-ef`, `refitter`; `dotnet` sets `LASTEXITCODE=1` for `refitter` → `dotnet` invoked with `tool update -g dotnet-ef` and `tool update -g refitter`; `Write-Red` with `Failed to update .NET tool: refitter`; cache `DotnetTools` is exactly `refitter`.
- [ ] **Step 2: Run the test command, expect FAIL.**
- [ ] **Step 3: Implement** with the copy from Global Constraints. `Update-Apps` runs `scoop update` (output visible) before computing the list. Set `$global:LASTEXITCODE = 0` before each external call so a stale code cannot mark a success as failed.
- [ ] **Step 4: Run the test command, expect PASS.**
- [ ] **Step 5: Commit** `feat(profile): Update-Apps on Scoop, Update-DotnetTools, CurrentUser module updates`.

### Task 5: Profile fragment and timer

**Files:**
- Modify (rewrite): `home/dot_profile/check-updates.ps1.tmpl`

**Interfaces:**
- Consumes: `Test-PackageUpdatesCacheStale`, `Update-PackageUpdatesCache` (autoloaded from the module).
- Produces: `$Global:PackageUpdatesDeclared = @{ Apps = @(…); Modules = @(…); DotnetTools = @(…) }`; event subscriber `PackageUpdates-Timer`; jobs named `PackageUpdates-Refresh`.

- [ ] **Step 1: Rewrite the fragment.** Lists rendered once:
  `Apps` from `{{ range .packages.windows.profiles }}{{ range (get . "scoop" | default list) }}` with `{{ splitList "/" . | last | squote }}`; `Modules` from the same profiles' `modules`; `DotnetTools` from `{{ range .packages.global.profiles }}` … `dotnet_tools`. Timer per R13: 30-minute interval, `AutoReset`, action body:
  ```powershell
  Get-Job -Name PackageUpdates-Refresh -ErrorAction SilentlyContinue | Where-Object State -ne Running | Remove-Job
  if (Get-Job -Name PackageUpdates-Refresh -ErrorAction SilentlyContinue) { return }
  if (-not (Test-PackageUpdatesCacheStale)) { return }
  $declared = $Global:PackageUpdatesDeclared
  Start-ThreadJob -Name PackageUpdates-Refresh -ScriptBlock {
      Import-Module PackageUpdates -DisableNameChecking
      Update-PackageUpdatesCache -Declared $using:declared
  } | Out-Null
  ```
  wrapped in `try { … } catch { }`.
- [ ] **Step 2: Render and parse:** `pwsh -NoProfile -Command '$t = Get-Content -Raw home/dot_profile/check-updates.ps1.tmpl | chezmoi --source . execute-template; $e=$null; [void][System.Management.Automation.Language.Parser]::ParseInput(($t -join "`n"),[ref]$null,[ref]$e); "errors=" + @($e).Count; $t'` → `errors=0`; the rendered `Apps` contains `'Hasklig-NF'`, `'windows-terminal'` and no `/`; `DotnetTools` has 12 items including `'refitter'`; `Modules` has 6 items.
- [ ] **Step 3: Load check without side effects:** in a `pwsh -NoProfile` child, define stubs `function scoop { throw 'called' }`, `function dotnet { throw 'called' }`, dot-source the rendered fragment from a `$env:TEMP` file, then assert `$Global:PackageUpdatesDeclared.Apps.Count -gt 0`, `Get-EventSubscriber -SourceIdentifier PackageUpdates-Timer` exists, no exception, and `Get-Module PackageUpdates` is `$null` (not imported at load, R14).
- [ ] **Step 4: Grep:** `git grep -n -i winget -- home/dot_profile/check-updates.ps1.tmpl home/readonly_Documents/PowerShell/Modules/PackageUpdates` → no output.
- [ ] **Step 5: Commit** `feat(profile): render declared lists and refresh updates in a thread job`.

### Task 6: Docs and VM acceptance

**Files:**
- Modify: `AGENTS.md:24`, `ReadMe.md:42`, `docs/testing.md:16-24`

- [ ] **Step 1: Edit docs (R15).** `AGENTS.md`: "Updating installed software is Scoop's job (`Update-Apps`), not chezmoi's." `ReadMe.md`: row `Upgrade apps, modules and .NET tools | Check-Updates, Update-Apps, Update-Modules, Update-DotnetTools (PowerShell profile)`. `docs/testing.md`: "Module tests (`tests/windows/Write-Pretty/`, `tests/windows/PackageUpdates/`)" and the run command pointed at `tests/windows`.
- [ ] **Step 2: Full host suite:** the test command with `tests/windows/Write-Pretty tests/windows/PackageUpdates` → all pass.
- [ ] **Step 3: Commit** `docs: update commands on Scoop with .NET tools` with `Fixes #45`; push; open a draft PR to `develop`.
- [ ] **Step 4: VM acceptance (owner, standard user):** after `C:\vagrant\run-tests.ps1 -BRANCH feat/45-check-updates-scoop`:
  - `Check-Updates -Now` lists only declared items (pin an older version first to have one: `scoop install jq@1.7` then `scoop hold`/`unhold` to see the held filter).
  - `Update-Apps`, `Update-Modules`, `Update-DotnetTools` run; a following `Check-Updates` shows no updated item.
  - With the cache deleted, open a terminal and wait for the tick (or temporarily call the timer action): typing stays responsive while `Get-Job PackageUpdates-Refresh` is `Running`; afterwards `%TEMP%\PackageUpdatesCache.json` exists.
  - Result recorded in the PR description; criteria 1, 2, 5 of the spec checked off there.
