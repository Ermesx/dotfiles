# Spec: Check-Updates on Scoop, with .NET global tools

Issue: [#45](https://github.com/Ermesx/dotfiles/issues/45) · ADR: [ADR-0003](../adr/0003-windows-packages-via-scoop.md) ·
Status: Draft · Date: 2026-11-20 · Plan: [`check-updates-scoop.plan.md`](check-updates-scoop.plan.md)

The issue fixes the direction (Scoop instead of winget, a .NET tools section, modules unchanged, declared packages
only, cache plus a background timer). This spec turns it into requirements and corrects what reading the code and
Scoop v0.6.0 showed (marked **[added]**).

## Decisions

| # | Decision | Agreed | Why |
|---|---|---|---|
| D1 | How the background check learns new app versions | **Variant A (2026-11-20):** the refresh runs `scoop update` (Scoop and buckets), then `scoop status --local` | **[added]** `scoop status` reads `Latest Version` from the manifest in the *local* bucket checkout (`app_status` → `manifest` → `manifest_path`); its own `git fetch` only feeds the "bucket(s) out of date" warning. Without `scoop update` the check never sees a new version |
| D2 | Where the refresh runs | **In a thread job (2026-11-20)**, started by the timer; the timer action itself only checks staleness | **[added]** A `Register-ObjectEvent -Action` block runs on the session's runspace when it is idle, so a slow `scoop update` / `Find-Module` / NuGet call would freeze the prompt. D1 makes the refresh slower than the winget version was |
| D3 | Refresh cadence across terminals | **Agreed 2026-11-20:** one shared cache in `%TEMP%`; the timer ticks every 30 minutes and starts a refresh only when the cache is older than 4 hours or missing; the refresh claims the slot by writing `lastRun` before it starts | Keeps the issue's 4-hour freshness without N terminals each pulling the buckets (git lock collisions), and a new terminal gets data within 30 minutes instead of 4 hours |
| D4 | Where the code lives | **Agreed 2026-11-20:** a new module `PackageUpdates` next to `Write-Pretty` (`home/readonly_Documents/PowerShell/Modules/`); `check-updates.ps1.tmpl` keeps only the rendered declared lists and the timer | A thread job starts with an empty runspace and must import the code; a module is also testable on the host with Pester, which a profile fragment is not |
| D5 | The "helper view from #43" in the issue | **[added]** Does not exist (dropped in the PR #50 review, `scoop-user-scope.md` R2); the template reads `packages.yaml` directly | `docs/packages.md` |

## Requirements

### Declared lists (`home/dot_profile/check-updates.ps1.tmpl`)

- **R1** The fragment renders one global hashtable `$Global:PackageUpdatesDeclared` with keys `Apps`, `Modules`,
  `DotnetTools` (string arrays), each rendered once:
  - `Apps`: every `scoop` item of `.packages.windows.profiles.*`, with the `bucket/` prefix stripped
    (`nerd-fonts/Hasklig-NF` → `Hasklig-NF`).
  - `Modules`: every `modules` item of `.packages.windows.profiles.*`.
  - `DotnetTools`: every `dotnet_tools` item of **`.packages.global.profiles.*`** **[added: the current template
    reads only `windows`]**.
- **R2** The fragment does no network or process work at load: it sets the hashtable, registers the timer (R13) and
  nothing else. It contains no reference to winget.

### Module `PackageUpdates`

Layout as `Write-Pretty`: `PackageUpdates.psd1`, `PackageUpdates.psm1` (dot-sources `private/` and `public/`,
exports public), one function per file. Every public function takes `-Declared [hashtable]`, defaulting to
`$Global:PackageUpdatesDeclared`. Every update row is `[pscustomobject]@{ Name; Old; New }`. Comparisons of names
are case-insensitive.

- **R3 Apps check.** Runs `scoop status --local` with the information stream dropped (`6>$null`: Scoop's
  `warn`/`success` use `Write-Host` and would print into the prompt from the timer). Keeps objects that have a
  non-empty `Latest Version`, whose `Info` does not contain `Held package`, and whose `Name` is in `Apps`. Maps
  `Installed Version` → `Old`, `Latest Version` → `New`. **[added]** Status also lists failed, deprecated, removed
  and missing-dependency apps with an empty `Latest Version`; those are not updates.
- **R4 Modules check.** For each name in `Modules` only **[added: today it queries the Gallery for every installed
  module]**: the newest `Get-InstalledModule -Name` and `Find-Module -Name`; a row when the Gallery version is
  greater. A module missing locally or in the Gallery is skipped.
- **R5 .NET tools check.** Installed versions from `dotnet tool list -g --format json` (`data[].packageId`,
  `data[].version`; verified on SDK 10.0.115). For each installed id in `DotnetTools`: versions from
  `https://api.nuget.org/v3-flatcontainer/<id lowercased>/index.json`, prereleases (containing `-`) dropped, the
  highest as `[version]`; a row when it is greater than the installed one. A failed request skips that tool only.
  Declared but not installed tools are skipped (installing is chezmoi's job).
- **R6 Cache.** One file `%TEMP%\PackageUpdatesCache.json`: `{ lastRun (ISO 8601), apps, modules, dotnetTools }`.
  A missing, empty or unparsable file reads as "no data" (`lastRun` = none, empty sections), never as an error.
  **[added]** The old winget-era files (`AppUpdatesCache.json`, `ModuleUpdatesCache.json`,
  `UpdatesCacheLastRun.txt`) are not read; the new file name keeps winget ids from reaching `scoop update`. The old
  files are left to the `%TEMP%` cleanup.
- **R7 Refresh.** `Update-PackageUpdatesCache`: writes the cache with the current `lastRun` and the old sections
  first (the claim, D3), runs `scoop update` with all output dropped, then R3, R4, R5, and writes the cache with all
  three sections. A failing `scoop update` does not stop the checks (they run on the local data).
- **R8 `Check-Updates [-Now]`.** `-Now` runs R7 in the foreground; without it, reads the cache. Prints, for each
  non-empty section, a green header (`__APPS__`, `__MODULES__`, `__DOTNET TOOLS__`) and the rows with
  `Write-PrettyTable`, then one line `Last checked: <lastRun>`. With no data: one line
  `No update data yet. Run Check-Updates -Now.`
- **R9 `Update-Apps`.** `► Updating Scoop and buckets` and `scoop update`; then the list from R3 computed fresh (not
  from the cache); then for each row a line ` - Updating <Name> [<Old> => <New>]` and `scoop update <Name>`. A
  non-zero `$LASTEXITCODE` **[added: Scoop aborts with `exit 1`, it does not throw]** prints
  `Failed to update app: <Name>` in red and the loop continues. Finally the `apps` section of the cache is
  replaced by the rows that failed; `lastRun` and the other sections are kept.
- **R10 `Update-Modules`.** Same shape: list from R4 computed fresh; `Update-Module -Name <n> -Scope CurrentUser
  -Force -ErrorAction Stop` **[added: explicit scope, a standard user cannot write AllUsers]**; a thrown error
  prints `Failed to update module: <Name>` and continues; the `modules` section is replaced by the failures.
- **R11 `Update-DotnetTools`.** Same shape: list from R5 computed fresh; `dotnet tool update -g <id>`; non-zero
  `$LASTEXITCODE` prints `Failed to update .NET tool: <Name>` and continues; the `dotnetTools` section is replaced
  by the failures.
- **R12** Progress lines in the `Update-*` functions use the `Write-Pretty` helpers already used by the old file
  (`Write-Cyan "► …"`, `Write-Yellow`, `Write-Green`, `Write-Red`). The module declares `Write-Pretty` in
  `RequiredModules`.

### Timer (`check-updates.ps1.tmpl`)

- **R13** If no subscriber `PackageUpdates-Timer` exists: a `System.Timers.Timer` with a 30-minute interval,
  `AutoReset`, registered with `Register-ObjectEvent`. The action: remove finished jobs named
  `PackageUpdates-Refresh`; if one is still running, return; if `Test-PackageUpdatesCacheStale` (cache missing or
  `lastRun` older than 4 hours) is false, return; otherwise
  `Start-ThreadJob -Name PackageUpdates-Refresh` with a script block that imports `PackageUpdates` and calls
  `Update-PackageUpdatesCache -Declared $using:declared`. The action never writes to the host and swallows errors.
- **R14** The profile does not import `PackageUpdates` at load; the first timer tick or the first command
  autoloads it (`~/Documents/PowerShell/Modules` is on `PSModulePath`). The thread job imports it with
  `-DisableNameChecking` (`Check-Updates` uses an unapproved verb; the name stays for the user).

### Docs

- **R15** `AGENTS.md`: the update rule names `Update-Apps` without "rewritten in #45". `ReadMe.md` (daily-use
  table): `Check-Updates`, `Update-Apps`, `Update-Modules`, `Update-DotnetTools`. `docs/testing.md`: module tests
  name both module test folders. ADR-0002 (accepted) is not edited.

## Acceptance criteria

1. `Check-Updates -Now` lists outdated declared Scoop apps, modules and .NET tools, nothing undeclared, no held app.
2. `Update-Apps`, `Update-Modules`, `Update-DotnetTools` update, continue after a single failure, and the next
   `Check-Updates` shows only what failed.
3. `check-updates.ps1.tmpl` and the module contain no winget reference.
4. Profile load does not do the check: the fragment renders and parses, and it calls no `scoop`, `dotnet`,
   `Find-Module` or web request (grep).
5. While a refresh runs from the timer, the prompt stays responsive (VM, by hand).

Criteria 1, 2 and 5 are checked in the VM as a standard user (Scoop is not on the host); the module logic is
covered by Pester on the host with `scoop`, `dotnet`, `Find-Module`, `Get-InstalledModule` and `Invoke-RestMethod`
mocked.

## Out of scope

Selection by profile (#20: the declared lists will be filtered once it lands), Linux (#12), updating Scoop apps not
declared in `packages.yaml`, uninstalling, a VM test that asserts updates (#47).
