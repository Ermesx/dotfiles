# Composable Install Profiles Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Each machine installs `base` plus the profiles and `pick` items chosen at `chezmoi init`, and every consumer (install scripts, PowerShell profile, Check-Updates, lazygit, Claude config, admin step, tests) follows that choice.

**Architecture:** `.chezmoi.toml.tmpl` stores `profiles`, `picks.<profile>` and `offered.<profile>` (prompted once, or taken from `DOTFILES_*` environment variables). One shared template `home/.chezmoitemplates/packages.tmpl` turns `packages.yaml` + that data into a filtered JSON view; every consumer reads the view and checks tools by name, never by profile.

**Tech Stack:** chezmoi v2.73 templates (sprig), PowerShell 7, Pester 6, Scoop, GitHub Actions, Vagrant.

**Spec:** [`install-profiles.md`](install-profiles.md) (D1–D15, R1–R35, approved 2026-11-25) · ADR: [ADR-0005](../adr/0005-composable-install-profiles.md).

## Global Constraints

- Branch `feat/20-install-profiles`; Conventional Commits with scope (`feat(profiles): …`, `test(profiles): …`); the last commit carries `Fixes #20`. Push only this branch: `git push origin feat/20-install-profiles` (`push.default = matching` would also try `develop`).
- **Never decrypt; never `chezmoi apply` / `install.ps1` on the host.** Static tests go through `Invoke-ChezmoiCi` (no-key config).
- Always `--source <repo root>`; never the installed source.
- Line endings: `*.ps1`, `*.psm1`, `*.ps1.tmpl` CRLF, no BOM; `*.yml`, `*.md`, `*.yaml`, other `*.tmpl` LF (`git ls-files --eol <f>`).
- Test header `#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '6.0.0' }`.
- Static command: `pwsh -NoProfile -Command 'Import-Module Pester -MinimumVersion 6.0.0; Invoke-Pester tests/static -Output Detailed'`.
- Data keys (exact): `.profiles` (list of profile names, `base` never stored), `.picks.<profile>` (list of labels), `.offered.<profile>` (list of labels). A label is the item with the bucket stripped (`splitList "/" . | last`).
- Env vars (exact): `DOTFILES_PROFILES` (comma-separated; `base` allowed and dropped), `DOTFILES_PICKS_<PROFILE>` (profile name upper-cased, comma-separated labels).
- Prompt texts (exact): `Profiles`, `<profile> items` (e.g. `apps items`).
- No `Get-Command` guards in chezmoi scripts or fragments: what exists is decided by the selection (memory rule, ADR-0005).

## Review Focus

1. **A machine initialised before #20** (config without `profiles`) runs `chezmoi apply` before re-init → everything selected, same as today (R7). Task 1 test `selects everything when no selection is stored`.
2. **Typo in `DOTFILES_PROFILES` / `DOTFILES_PICKS_*`** (`shel`) → init fails naming `shel` and the valid choices, never "nothing selected". Task 2 test `fails on an unknown profile in DOTFILES_PROFILES`.
3. **`pick` profile selected with no items** (`picks.apps = []`) → no `apps` item in the view, no error. Task 1 test `includes no item of a pick profile with no picks`.
4. **A stored pick no longer in the YAML** (item removed) → ignored by the view, not in `pending`, no failure. Task 1 test `ignores a stored pick that is no longer declared`.
5. **`chezmoi init --prompt` loses earlier picks** → defaults are the stored picks plus new items (R2). Task 2 test `keeps stored picks and preselects new items with --promptDefaults`.

---

### Task 1: The view (R6–R10, D13; R28 view part)

**Files:**
- Create: `home/.chezmoitemplates/packages.tmpl`, `tests/static/View.Tests.ps1`
- Modify: `tests/static/StaticChecks.psm1` (`Invoke-ChezmoiCi`, new `Get-PackagesView`, export)

**Interfaces:**
- Produces (template): `includeTemplate "packages.tmpl" . | fromJson` → object with keys:
  `profiles` ([string], selected incl. `base`), one key per list method on the platform (`scoop`, `modules`, `dotnet_tools`, `yazi_plugins`; Linux `brew`, `zsh_plugins`) → [string] YAML items, `wsl` (string, `""` if none), `tools` ([string] labels of scoop items + modules + dotnet tools + yazi plugins), `pending` (map profile → [label]; empty map when `.offered` missing).
- Produces (PowerShell): `Invoke-ChezmoiCi … [-Data [hashtable]]` → adds `--override-data (ConvertTo-Json $Data -Depth 5 -Compress)`; `Get-PackagesView -Source <root> [-Data <hashtable>] [-NoCi]` → the parsed view (`ConvertFrom-Json`).

- [ ] **Step 1: Write `View.Tests.ps1`** with `Get-PackagesView -Source $root -Data …` and these `It`s:
  - `selects everything when no selection is stored`: no `-Data` → `profiles` contains `base, shell, sdk, containers, apps, ai`; `scoop` contains `extras/rider`, `claude-code`.
  - `selects only base and the chosen profiles`: `@{ profiles = @('shell') }` → `profiles` = `base, shell`; `scoop` contains `starship`, not `dotnet-sdk`; `modules` contains `PSfzf`, not `Pester`.
  - `merges global into the platform`: `@{ profiles = @('sdk') }` → `dotnet_tools` contains `dotnet-ef`; `@{ profiles = @('shell') }` → `yazi_plugins` contains `yazi-rs/plugins:full-border`, `dotnet_tools` empty.
  - `takes only picked items of a pick profile`: `@{ profiles = @('apps'); picks = @{ apps = @('rider') } }` → `scoop` contains `extras/rider`, not `extras/postman`.
  - `includes no item of a pick profile with no picks`: `picks = @{ apps = @() }` → no `apps` item in `scoop`.
  - `ignores a stored pick that is no longer declared`: `picks = @{ apps = @('rider','gone') }` → renders, `scoop` contains `extras/rider`.
  - `strips buckets in tools`: full view `tools` contains `vscode`, `rider`, `Hasklig-NF`, `PSfzf`, `dotnet-ef`; not `extras/vscode`.
  - `has no WSL distro without sdk`: `profiles = @('shell')` → `wsl` is `''`; full view → `Ubuntu-24.04`.
  - `lists items not offered yet as pending`: `profiles = @('apps'); picks = @{apps=@('rider')}; offered = @{ apps = @('rider','googlechrome','postman') }` → `pending.apps` = `@('vagrant')`; without `offered` → `pending` has no keys.
  - `renders the same bytes twice` (R10): two renders of the full view are `-ceq`.
  - `has unique labels in every pick profile` (D13): from `Get-PackagesData`, for each profile with `pick`, labels (`($_ -split '/')[-1]`) have no duplicates.
- [ ] **Step 2: Run** `Invoke-Pester tests/static/View.Tests.ps1` → FAIL (`Get-PackagesView` not found).
- [ ] **Step 3: Implement** `Invoke-ChezmoiCi -Data`, `Get-PackagesView` (renders `{{ includeTemplate "packages.tmpl" . }}` via `execute-template`), and `packages.tmpl`. Rules: platform = `.chezmoi.os`; selected = `base` + `.profiles`, or every profile when `.profiles` is absent (`hasKey . "profiles"`); for a profile with `pick: true`, keep an item only if its label is in `.picks.<profile>` (absent `.profiles` → keep all); dedupe with `uniq`; profiles iterated alphabetically (map order), items in YAML order; output with `toJson`.
- [ ] **Step 4: Run** `Invoke-Pester tests/static/View.Tests.ps1` → all PASS; then the full static command → PASS.
- [ ] **Step 5: Commit** `feat(profiles): packages view filtered by the selection`.

### Task 2: Selection at init (R1–R5, D3, D8, D11, D14, D15)

**Files:**
- Modify: `home/.chezmoi.toml.tmpl` (append the selection block and `[data]`)
- Create: `tests/static/Selection.Tests.ps1`

**Interfaces:**
- Consumes: `packages.yaml` profile names and `pick` flags (read directly here: the view needs the selection, so the config template cannot use it).
- Produces: `[data] profiles`, `[data.picks] <profile>`, `[data.offered] <profile>` as in Global Constraints.

- [ ] **Step 1: Write `Selection.Tests.ps1`.** Helper `Invoke-InitTemplate([hashtable]$Env, [string[]]$Flags, [string]$Existing)` writes `$Existing` to a temp config, runs `chezmoi --source $root --config <it> execute-template --init --no-tty @Flags` on `home/.chezmoi.toml.tmpl` with `$Env` set in the process (restored in `finally`), and returns `{ Output; ExitCode; Error }`; tests assert on the rendered TOML with `Should -Match`.
  - `takes profiles from DOTFILES_PROFILES`: `DOTFILES_PROFILES='shell,sdk'` → output matches `profiles = \["sdk", "shell"\]` or `\["shell", "sdk"\]` (order as given is fine; assert both names and no `apps`).
  - `treats base alone as only base`: `DOTFILES_PROFILES='base'` → `profiles = \[\]`.
  - `fails on an unknown profile in DOTFILES_PROFILES`: `'shel'` → exit code ≠ 0, error contains `shel` and `shell`.
  - `takes picks from DOTFILES_PICKS_AI`: `DOTFILES_PROFILES='ai'`, `DOTFILES_PICKS_AI='claude-code'` → `ai = \["claude-code"\]` under `[data.picks]`.
  - `fails on an unknown pick`: `DOTFILES_PICKS_APPS='ridr'` with `apps` selected → non-zero, names `ridr`.
  - `writes offered for every pick profile`: any selection → `[data.offered]` has `apps` with `rider`, `googlechrome`, `postman`, `vagrant` and `ai` with `claude-code`.
  - `keeps stored picks and preselects new items with --promptDefaults`: `$Existing` = `[data] profiles=["apps"]`, `[data.picks] apps=["rider"]`, `[data.offered] apps=["rider","googlechrome"]`; flags `--prompt --promptDefaults` → `apps = ["rider","postman","vagrant"]` (stored + not offered; `googlechrome` stays off).
  - `keeps the stored answer without --prompt`: `$Existing` with `profiles=["shell"]`, no env, no flags → `profiles = ["shell"]`.
- [ ] **Step 2: Run** `Invoke-Pester tests/static/Selection.Tests.ps1` → FAIL.
- [ ] **Step 3: Implement** in `.chezmoi.toml.tmpl`: choices = profile names of `global` ∪ `<os>` minus `base`, sorted; `DOTFILES_PROFILES` set → `splitList ","`, drop `base`, `fail` on a name not in choices (message: `DOTFILES_PROFILES: unknown profile "<x>"; choose from <choices>`); else `promptMultichoiceOnce . "profiles" "Profiles" $choices (get . "profiles" | default $choices)`. For each pick profile (sorted) on the platform: labels of its items (platform + global); `offered.<p>` = labels; if selected: env `DOTFILES_PICKS_<UPPER>` → same parsing and `fail`; else `promptMultichoiceOnce . (print "picks." $p) (print $p " items") $labels $default` with `$default` = stored picks (`dig "picks" $p nil .`) plus labels not in stored `offered`, or all labels when nothing is stored. Emit `[data] profiles`, `[data.picks]`, `[data.offered]` with `toToml`.
- [ ] **Step 4: Run** the test file → PASS; full static → PASS (`Templates.Tests` renders the config template too).
- [ ] **Step 5: Commit** `feat(profiles): choose profiles and picks at chezmoi init`.

### Task 3: Packages and install scripts follow the view (R11–R16, R25, D4)

**Files:**
- Modify: `home/.chezmoidata/packages.yaml`, `home/.chezmoiscripts/windows/run_onchange_before_01-scoop.ps1.tmpl`, `run_onchange_before_02-modules.ps1.tmpl`, `run_onchange_before_03-dotnet-tools.ps1.tmpl`, `run_once_after_yazi-plugins.ps1.tmpl`, `run_once_before_install-wsl.ps1.tmpl`, `tests/static/ContainerEngine.Tests.ps1`
- Delete: `home/.chezmoidata/ci.yaml`, `tests/static/CiProfiles.Tests.ps1`
- Create: `tests/static/InstallScripts.Tests.ps1`

**Interfaces:**
- Consumes: Task 1 view and `Invoke-ChezmoiCi -Data`.

- [ ] **Step 1: Write `InstallScripts.Tests.ps1`** (render each script with `Invoke-ChezmoiCi -Arguments execute-template -InputText (Get-Content -Raw <script>) -Data …`):
  - `installs base and shell only`: `profiles=@('shell')` → Scoop script contains `scoop install extras/vscode`, `scoop install delta`, `scoop install less`, `scoop install jq`, `scoop install starship`; not `scoop install dotnet-sdk`, not `scoop install extras/rider`.
  - `installs only picked apps`: `profiles=@('apps'); picks=@{apps=@('postman')}` → `scoop install extras/postman`, not `extras/rider`.
  - `ignores CI for the selection`: same `-Data`, with and without `-NoCi` → identical output.
  - `renders no WSL script without a distro`: `profiles=@('shell')` → install-wsl output is whitespace only; full → contains `Ubuntu-24.04`.
  - `renders no yazi script without shell`: `profiles=@('sdk')` → yazi output whitespace only.
  - `installs modules and .NET tools of the selection`: `profiles=@('shell')` → modules script contains `PSfzf`, not `Pester`; dotnet script has no `dotnet tool install`.
- [ ] **Step 2: Run** → FAIL.
- [ ] **Step 3: Implement.** Move `extras/vscode`, `delta`, `less`, `jq` to `windows.profiles.base.scoop` (R11), update the header comment (R12). Each script: `{{- $v := includeTemplate "packages.tmpl" . | fromJson }}` and range over `$v.<method>`; buckets from `$v.scoop`; remove the `CI` / `$skip` lines. Scripts that have nothing to do wrap their whole body in `{{ if $v.<method> }}` so they render empty (R15). Delete `ci.yaml` and `CiProfiles.Tests.ps1`; in `ContainerEngine.Tests.ps1` replace the CI-skip expectations with `-Data @{ profiles = @('shell') }` (no `DockerCompletion`) vs. `@{ profiles = @('containers') }` (imports it) — the profile part lands in Task 4, so here only the Scoop part.
- [ ] **Step 4: Run** the full static suite → PASS (`Packages.Tests` checks the moved items' manifests).
- [ ] **Step 5: Commit** `feat(profiles): install scripts follow the selection`.

### Task 4: PowerShell profile per tool (R17–R22)

**Files:**
- Create: `home/dot_profile/general_profile.ps1`, `home/dot_profile/tools/{bat,fd,ripgrep,delta,starship,dotnet-sdk,Terminal-Icons,yazi,zoxide,PSfzf,onefetch}.ps1`, `home/dot_profile/tools/chezmoi.ps1.tmpl`, `tests/static/Profile.Tests.ps1`
- Delete: `home/dot_profile/completers_profile.ps1.tmpl`, `z_inits_profile.ps1`, `psfzf_profile.ps1`, `onefetch_profile.ps1`
- Modify: `home/readonly_Documents/PowerShell/Microsoft.PowerShell_profile.ps1.tmpl`, `home/.chezmoiignore`, `home/dot_profile/check-updates.ps1.tmpl`, `home/dot_profile/user-setup_profile.ps1.tmpl`, `tests/static/ContainerEngine.Tests.ps1` (profile part)

**Interfaces:**
- Consumes: view `tools`, `modules`, `scoop`, `wsl`.
- Produces: rule "fragment `tools/<name>.ps1` exists ⇔ `<name>` ∈ `tools`", used by Task 4's ignore block and the orphan test.

- [ ] **Step 1: Write `tests/static/Profile.Tests.ps1`:**
  - `has a tool in the full view for every fragment`: each `home/dot_profile/tools/*` basename (without `.ps1`/`.ps1.tmpl`) ∈ full view `tools`.
  - `dot-sources only selected tools`: render the profile template with `profiles=@()` → contains `tools/chezmoi.ps1` and `tools/delta.ps1`; not `tools/bat.ps1`, not `Import-Module -Name 'PSfzf'`.
  - `loads zoxide last and starship before it`: full render → the last `. '…tools/…'` line is `zoxide.ps1`; index of `starship.ps1` < index of `zoxide.ps1`.
  - `ignores fragments of unselected tools`: `Get-ManagedPath`-style `managed` with `-Data @{ profiles=@() }` → no `.profile/tools/bat.ps1`; full → present.
  - `declares only selected apps for Check-Updates`: render `check-updates.ps1.tmpl` with `profiles=@('shell')` → contains `'starship'`, not `'dotnet-sdk'`.
  - `skips the WSL part of Complete-UserSetup without a distro`: `profiles=@('shell')` → no `wsl --install`; still `ssh-add`.
- [ ] **Step 2: Run** → FAIL.
- [ ] **Step 3: Implement.** Move code per the R18 table verbatim into the fragments (completer lines, `Invoke-Starship-TransientFunction` + init + `Enable-TransientPrompt`, `y`, zoxide init, PSfzf file, onefetch file, `Set-TerminalIconsIcon`); `general_profile.ps1` = aliases `gi`, `file` + `winget` completer. Profile template: hashes over `dot_profile/*.ps1*` and `dot_profile/tools/*`; `Import-Module` for `$v.modules`; dot-source general fragments by glob (as today), then `tools/<name>.ps1` for each `name` in a fixed order list `bat fd ripgrep delta chezmoi dotnet-sdk Terminal-Icons yazi PSfzf onefetch starship zoxide` filtered by `has name $v.tools`. `.chezmoiignore`: for every fragment in `dot_profile/tools/` whose name ∉ `$v.tools`, ignore `.profile/tools/<name>.ps1`. `check-updates`: `Apps` from `$v.scoop` labels, `Modules` from `$v.modules`. `Complete-UserSetup`: WSL block inside `{{ if $v.wsl }}`.
- [ ] **Step 4: Run** full static → PASS.
- [ ] **Step 5: Commit** `feat(profiles): PowerShell profile loads only selected tools`.

### Task 5: Claude configuration only with claude-code (R23–R24, D6)

**Files:**
- Rename: `home/readonly_AppData/Local/lazygit/config.yml` → `config.yml.tmpl`
- Modify: `home/.chezmoiignore`
- Create: `tests/static/ClaudeConfig.Tests.ps1`, `tests/static/fixtures/lazygit-config.yml`

- [ ] **Step 1: Write tests:**
  - `deploys no Claude config without claude-code`: `managed` with `profiles=@('shell')` → no path starting `.claude`, no `AppData/Local/lazygit/ai-commit.ps1`; with `profiles=@('ai'); picks=@{ai=@('claude-code')}` → both present.
  - `renders lazygit config unchanged with claude-code`: before renaming, copy today's `config.yml` to `tests/static/fixtures/lazygit-config.yml`; the full-view render `-ceq` that fixture.
  - `renders no AI command without claude-code`: `profiles=@('shell')` → no `<c-a>`, no `customCommands:`; output still contains `editPreset: 'vscode'`.
- [ ] **Step 2: Run** → FAIL.
- [ ] **Step 3: Implement.** First line of `config.yml.tmpl`: `# chezmoi:template:left-delimiter="[[" right-delimiter="]]"`; the view call and the `customCommands:` block (to end of file) inside `[[ if has "claude-code" $v.tools ]] … [[ end ]]`; lazygit's `{{…}}` stay as written. `.chezmoiignore`: `.claude` and `AppData/Local/lazygit/ai-commit.ps1` when `claude-code` ∉ tools (keep the existing Windows `.claude/*` allowlist inside the `else`).
- [ ] **Step 4: Run** full static → PASS.
- [ ] **Step 5: Commit** `feat(profiles): Claude config only where claude-code is selected`.

### Task 6: Admin step asks for WSL only where needed (R32–R34, D12)

**Files:**
- Rename: `home/.chezmoiscripts/windows/run_after_zz-admin-reminder.ps1` → `.ps1.tmpl`; `home/dot_config/dotfiles/admin/admin-setup.ps1` → `.ps1.tmpl`
- Modify: `home/.chezmoiignore`, `tests/windows/AdminSetup/Admin-Reminder.Tests.ps1`, `tests/windows/AdminSetup/Admin-Setup.Tests.ps1`, `tests/windows/AdminSetup/Complete-UserSetup.Tests.ps1` (reads `sdk.wsl` by path: take it from the view), `tests/static/InstallScripts.Tests.ps1`

**Interfaces:**
- Produces: "WSL needed" = `or $v.wsl (has "rancher-desktop" $v.tools)`.
- Test helper (both admin test files): `Get-RenderedScript([string]$Relative, [hashtable]$Data)` → renders `home/<Relative>` with `chezmoi --source $root --config <empty temp> --override-data … execute-template`, writes it to `TestDrive:` with the original file name, returns the path.

- [ ] **Step 1: Write tests.** Existing tests render with the full view first (no behaviour change). New:
  - Reminder `does not mention WSL without a distro or Rancher`: `profiles=@('shell')`, `Mock wsl { $global:LASTEXITCODE = 1 }`, Developer Mode and agent present → prints nothing; `Should -Invoke wsl -Times 0`.
  - Reminder `still asks for WSL with containers only`: `profiles=@('containers')`, wsl fails → prints `Administrator step needed`.
  - Admin-setup `skips enable-wsl without a need`: `profiles=@('shell')` → log has `enable-developer-mode`, `enable-ssh-agent`, not `enable-wsl`.
  - In `tests/static/InstallScripts.Tests.ps1`, `deploys enable-wsl only where WSL is needed`: `managed` with `profiles=@('shell')` has no `.config/dotfiles/admin/enable-wsl.ps1`; with `profiles=@('containers')` it has.
- [ ] **Step 2: Run** `Invoke-Pester tests/windows/AdminSetup` and the static file → FAIL.
- [ ] **Step 3: Implement** the two templates (`{{ if $wslNeeded }}` around the WSL probe/condition and around `. "$PSScriptRoot\enable-wsl.ps1"`), and the ignore rule.
- [ ] **Step 4: Run** both → PASS.
- [ ] **Step 5: Commit** `feat(profiles): admin step asks for WSL only where it is needed`.

### Task 7: Notice for new pick items (R35, D11)

**Files:**
- Create: `home/.chezmoiscripts/windows/run_after_zz-new-picks.ps1.tmpl`, `tests/static/NewPicks.Tests.ps1`

- [ ] **Step 1: Write tests** (render with `-Data`):
  - `renders nothing when nothing is pending`: full view without `offered` → whitespace only; with `offered` equal to all labels → whitespace only.
  - `lists new items per profile`: `profiles=@('apps','ai'); picks=@{apps=@('rider'); ai=@('claude-code')}; offered=@{apps=@('rider','googlechrome','postman'); ai=@()}` → output contains `► New items to choose from (not installed):`, `apps: vagrant`, `ai:   claude-code` (labels joined with `, `, profile names padded to the longest + `:`), and `Choose with: chezmoi init --prompt; chezmoi apply`.
  - `ignores unselected profiles`: `profiles=@('shell')` with stale `offered` → whitespace only.
- [ ] **Step 2: Run** → FAIL.
- [ ] **Step 3: Implement**: whole body inside `{{ if $v.pending }}`; `Write-Host` lines as in R35 (first line Yellow); `exit 0`.
- [ ] **Step 4: Run** → PASS.
- [ ] **Step 5: Commit** `feat(profiles): notice for new items in pick profiles`.

### Task 8: CI and the VM select profiles (R26, R27, R29, D9)

**Files:**
- Modify: `.github/workflows/ci.yml` (apply step `env:`), `tests/run-tests.ps1`, `tests/windows/Installed-Apps-Modules.Tests.ps1`

- [ ] **Step 1: Change `Installed-Apps-Modules.Tests.ps1`**: `BeforeDiscovery` renders `{{ includeTemplate "packages.tmpl" . }}` with the machine's config (`chezmoi @sourceArgs execute-template`) and takes `apps` = `scoop` labels, `modules`, `tools` = `dotnet_tools`; drop `$skip`.
- [ ] **Step 2: `ci.yml`**: the "Apply dotfiles" step gets `env: DOTFILES_PROFILES: shell,sdk,ai` and `DOTFILES_PICKS_AI: claude-code`.
- [ ] **Step 3: `run-tests.ps1`**: params `[string[]]$Profiles`, `[hashtable]$Picks`; before `Invoke-Expression` set `$env:DOTFILES_PROFILES = $Profiles -join ','` (when given) and `$env:DOTFILES_PICKS_<KEY>` per `$Picks` entry, process scope only; install Pester (`Install-Module Pester -MinimumVersion 6.0.0 -Scope CurrentUser -Force -SkipPublisherCheck`) before `execute-pester.ps1` when missing.
- [ ] **Step 4: Verify** static suite PASS on the host; push and check the CI run is green (`gh run watch`).
- [ ] **Step 5: Commit** `ci(profiles): CI and the VM pass the selection in environment variables`.

### Task 9: Docs (R31) and VM acceptance

**Files:**
- Modify: `docs/packages.md`, `docs/chezmoi.md`, `docs/conventions.md`, `docs/testing.md`, `docs/architecture.md`, `AGENTS.md` (Commands row: `chezmoi init --prompt` — change the profile selection), `.claude/agents/docs-sync.md` (bindings source `psfzf_profile.ps1` → `tools/PSfzf.ps1`), `ReadMe.md` and `docs/terminal-bindings.md` (via the docs-sync agent)

- [ ] **Step 1: Update the docs** per R31; `docs/packages.md` gets: selection keys, env vars, the view keys, "condition on the tool, not the profile", how to add a profile and a pick item (and the notice). Remove "ignored until #20" and the "consumers read the tree directly" paragraph.
- [ ] **Step 2: Run the docs-sync agent** to regenerate the ReadMe package table and `docs/terminal-bindings.md` (fragments moved).
- [ ] **Step 3: Run** the full static suite → PASS (`Docs.Tests` link check).
- [ ] **Step 4: Commit** `docs(profiles): document install profiles` with `Fixes #20`.
- [ ] **Step 5: VM acceptance (owner runs or approves):** `vagrant up dotfiles-windows`; as the standard user `C:\vagrant\run-tests.ps1 -BRANCH feat/20-install-profiles -Profiles shell` → tests green, `$PROFILE` loads clean, no WSL in the reminder; then `-Profiles shell,sdk` → only `sdk` items newly installed, tests green.
