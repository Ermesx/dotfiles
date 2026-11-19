# Scoop User-Scope Install Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Windows setup installs every app, module, .NET tool and user setting without admin rights, through Scoop, from one package view.

**Architecture:** `packages.yaml` (platform → profile → method) is merged by one chezmoi template into a JSON view per method; every consumer reads the view. Numbered `run_onchange_before_` scripts install Scoop apps, modules and .NET tools; an `after_` script writes HKCU settings; WSL and SSH steps skip themselves when admin-only prerequisites are missing. DSC and winget are removed.

**Tech Stack:** chezmoi 2.73 templates (sprig), PowerShell 7 (scripts), Windows PowerShell 5.1 + 7 (`install.ps1`), Scoop, Pester 6.

**Spec:** [`docs/specs/scoop-user-scope.md`](scoop-user-scope.md) (requirements R1–R21, decisions D1–D5). ADR: [ADR-0003](../adr/0003-windows-packages-via-scoop.md).

## Global Constraints

- Branch `feat/43-scoop-user-scope`. Conventional Commits with a scope; the last commit carries `Fixes #43` and `Fixes #9`.
- `*.ps1`, `*.ps1.tmpl`: **CRLF** (`git ls-files --eol <file>` → `w/crlf` after `git add` + checkout, or write CRLF directly). Everything else LF.
- Never run `chezmoi apply`, `install.ps1`, `scoop install`, `Install-Module` or `dotnet tool install` on the host. Host checks only render, parse and run Pester on the view.
- Always `chezmoi --source .` from the repo root.
- Script progress lines: `Write-Host "► <Action>" -ForegroundColor Cyan`. No `Get-Command` guards for tools the earlier scripts install (memory: DSC/Scoop guarantee them); guards check target state.
- Template render check for any `.ps1.tmpl` (used in every task):
  `pwsh -NoProfile -Command '$t = Get-Content -Raw <file> | chezmoi --source . execute-template; $e=$null; [void][System.Management.Automation.Language.Parser]::ParseInput(($t -join "`n"),[ref]$null,[ref]$e); "errors=" + @($e).Count'` → `errors=0`.
- Decisions D1–D5 in the spec are confirmed by the owner (2026-11-19).

## Review Focus

1. **Tool installed earlier in the same apply is not on `PATH`/env** (`dotnet`, `ya`, `DOTNET_ROOT`) → R4 partial included in scripts 01, 03 and yazi; Task 2 Step 3 greps for the include, Task 8 VM run proves it.
2. **Inbox Pester 3.4 counts as installed** → `Get-InstalledModule` + `-SkipPublisherCheck` for Pester; Task 3 Step 1 greps, Task 7 VM test checks `Get-InstalledModule Pester`.
3. **An admin-only command disappears** while being removed from apply (Developer Mode, WSL platform, ssh-agent service) → parked in `scripts/admin/` (R21); Task 5 Step 3 greps that each command exists there and nowhere under `home/`.
4. **App stuck in Scoop's failed state** → summary hint `scoop uninstall <app>`; Task 8 Step 4 failure path.
5. **`install.ps1` started from an elevated shell** → clear `throw` before the Scoop installer; Task 6 Step 2 logic check with a stand-in.

---

### Task 1: Package data model, view and list consumers

**Files:**
- Modify: `home/.chezmoidata/packages.yaml` (replace with the #43 target, R1)
- Create: `home/.chezmoitemplates/packages.tmpl` (R2)
- Create: `tests/windows/Package-View.Tests.ps1` (R18)
- Modify: `home/readonly_Documents/PowerShell/Microsoft.PowerShell_profile.ps1.tmpl` (R16), `home/dot_profile/check-updates.ps1.tmpl` (D2: `$pkgs.scoop` / `$pkgs.modules` in both `quoteList` places), `home/dot_profile/completers_profile.ps1.tmpl` (R13)
- Delete: `home/.chezmoitemplates/config.dsc.yaml.tmpl`, `home/dot_config/config.dsc.yaml.tmpl`, `run_once_before_00-pre-dsc.ps1`, `run_onchange_before_01-dsc.ps1.tmpl`; remove the `config.dsc.yaml.tmpl` lines from `home/dot_config/.chezmoiignore` (R12)

**Interfaces:**
- Produces: view `includeTemplate "packages.tmpl" . | fromJson` → object with keys `scoop`, `modules`, `wsl`, `dotnet_tools`, `yazi_plugins` (lists of strings) on Windows. Test helper pattern for the source: `$src = Join-Path $PSScriptRoot '../..'; $sourceArgs = if (Test-Path (Join-Path $src '.chezmoiroot')) { @('--source', (Resolve-Path $src)) } else { @() }`; view = `'{{ includeTemplate "packages.tmpl" . }}' | chezmoi @sourceArgs execute-template | ConvertFrom-Json`.

- [ ] **Step 1: Write `Package-View.Tests.ps1`** (`#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '6.0.0' }`), view rendered in `BeforeAll`. Assertions (R18): `$view.PSObject.Properties.Name | Sort-Object` equals `dotnet_tools, modules, scoop, wsl, yazi_plugins`; `$view.scoop.Count | Should -Be 39`; `$view.scoop` contains `extras/windows-terminal`, `nerd-fonts/Hasklig-NF`, `claude-code`; `$view.modules | Sort-Object` equals `DockerCompletion, Pester, posh-git, powershell-yaml, PSfzf, Terminal-Icons`; `$view.dotnet_tools.Count | Should -Be 12`; `$view.wsl | Should -Be 'Ubuntu-24.04'`; `$view.yazi_plugins | Should -Be 'yazi-rs/plugins:full-border'`.
- [ ] **Step 2: Run, expect FAIL** (template missing): `pwsh -NoProfile -Command 'Import-Module Pester -MinimumVersion 6.0.0; Invoke-Pester tests/windows/Package-View.Tests.ps1 -Output Detailed'`.
- [ ] **Step 3: Replace `packages.yaml`** with the target block from #43 verbatim (`gh issue view 43`).
- [ ] **Step 4: Create `packages.tmpl`.** Algorithm (verified on chezmoi 2.73.1):

  ```gotemplate
  {{- $view := dict -}}
  {{- range $platform := list "global" .chezmoi.os -}}
  {{-   range $profile := (index $.packages $platform).profiles -}}
  {{-     range $method, $items := $profile -}}
  {{-       if ne $method "pick" -}}
  {{-         $_ := set $view $method (concat (get $view $method | default list) $items) -}}
  {{-       end -}}
  {{-     end -}}
  {{-   end -}}
  {{- end -}}
  {{- toJson $view -}}
  ```
- [ ] **Step 5: Run the test, expect PASS.**
- [ ] **Step 6: Switch consumers and delete DSC.** Profile: `{{- range (includeTemplate "packages.tmpl" . | fromJson).modules }}`. `check-updates`: one `{{- $pkgs := includeTemplate "packages.tmpl" . | fromJson }}` at the top, replace both pairs of `.packages.windows.wingets` / `.packages.windows.modules`. Completers: delete the `dsc` and `winget` blocks. Delete the DSC files listed above.
- [ ] **Step 7: Verify.** `chezmoi --source . managed` succeeds and lists no `config.dsc.yaml`; render check (Global Constraints) on the profile, `check-updates` and `completers` templates → `errors=0`; `git grep -n "packages\.windows\.\|packages\.dotnet_tools\|packages\.yazi" home` lists only `run_once_after_yazi-plugins.ps1.tmpl` and `run_once_before_install-wsl.ps1.tmpl` (Tasks 5 and 2).
- [ ] **Step 8: Commit** `refactor(packages): profile-based schema with a merged package view` (all files above).

### Task 2: Environment refresh partial and Scoop install script

**Files:**
- Create: `home/.chezmoitemplates/refresh-env.ps1` (R4), `home/.chezmoiscripts/windows/run_onchange_before_01-scoop.ps1.tmpl` (R5)
- Modify: `home/.chezmoiscripts/windows/run_once_after_yazi-plugins.ps1.tmpl` (R11)

**Interfaces:**
- Consumes: the view (Task 1).
- Produces: partial included as `{{ template "refresh-env.ps1" . }}`; it defines no functions, only mutates `$env:`.

- [ ] **Step 1: `refresh-env.ps1`:** loop over `[Environment]::GetEnvironmentVariables('User')` setting each `$env:` entry, then `$env:PATH = "$userPath;$machinePath"` from the `User` and `Machine` values.
- [ ] **Step 2: Scoop script** per R5. Render-time: `{{ $pkgs := includeTemplate "packages.tmpl" . | fromJson }}`; buckets via `splitList "/"` on items containing `/`, then `uniq`; emit `$buckets = @(...)` and `$apps = @(...)` with `squote`. Run-time: include the partial; `$known = (scoop bucket list).Name`; add missing buckets, recording a failure when `$LASTEXITCODE -ne 0`; `foreach ($app in $apps) { scoop install $app }`; `$installed = scoop list`; failed = apps whose `($app -split '/')[-1]` is not in `$installed.Name` or whose entry's `Info -match 'failed'`; summary lines `  ✗ <app>  (clear with: scoop uninstall <name>; then chezmoi apply)`; `exit 1` if any failure.
- [ ] **Step 3: Yazi script:** add the partial at the top and range over `(includeTemplate "packages.tmpl" . | fromJson).yazi_plugins`.
- [ ] **Step 4: Verify.** Render check on both scripts → `errors=0`; the rendered scoop script contains `'extras'`, `'nerd-fonts'` in `$buckets` exactly once each and 39 entries in `$apps`; `git grep -l 'template "refresh-env.ps1"' home` lists the scoop and yazi scripts; `chezmoi --source . managed --include=scripts` shows `01-scoop.ps1`.
- [ ] **Step 5: Commit** `feat(packages): install Windows apps with Scoop`.

### Task 3: PowerShell modules and .NET tools

**Files:**
- Create: `run_onchange_before_02-modules.ps1.tmpl` (R6), `run_onchange_before_03-dotnet-tools.ps1.tmpl` (R7) in `home/.chezmoiscripts/windows/`

**Interfaces:** Consumes the view and the R4 partial (03 only).

- [ ] **Step 1: Modules script** per R6. Exact checks: `(Get-PSRepository -Name PSGallery).InstallationPolicy -ne 'Trusted'` → `Set-PSRepository -Name PSGallery -InstallationPolicy Trusted`; `$installed = (Get-InstalledModule -ErrorAction SilentlyContinue).Name`; per missing module `Install-Module -Name $m -Scope CurrentUser -Force -ErrorAction Stop` inside `try/catch`, plus `-SkipPublisherCheck` when `$m -eq 'Pester'` (comment: inbox Pester 3.4 has another publisher). Summary + `exit 1` as in Task 2.
- [ ] **Step 2: .NET tools script** per R7: `$installed = dotnet tool list -g | Select-Object -Skip 2 | ForEach-Object { ($_ -split '\s+')[0] }`; per missing tool `dotnet tool install -g $t`, failure when `$LASTEXITCODE -ne 0`. Summary + `exit 1`.
- [ ] **Step 3: Verify.** Render check on both → `errors=0`; `git grep -n "Get-Module -ListAvailable" home/.chezmoiscripts` → nothing; `managed --include=scripts` shows `02-modules.ps1`, `03-dotnet-tools.ps1` after `01-scoop.ps1`.
- [ ] **Step 4: Commit** `feat(packages): install modules and .NET tools in user scope`.

### Task 4: User settings in HKCU

**Files:** Create `home/.chezmoiscripts/windows/run_onchange_after_user-settings.ps1` (R8).

- [ ] **Step 1: Write the script** per R8: one hashtable `@{ HideFileExt = 0; Hidden = 1; ShowSecondsInSystemClock = 1 }`, compare with `Get-ItemPropertyValue` (missing value = differs), `Set-ItemProperty -Type DWord` on difference, `$changed = $true`; at the end `if ($changed) { Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue }`.
- [ ] **Step 2: Verify.** Parse with `[Parser]::ParseFile` → `errors=0`; `git grep -n "HKLM" home/.chezmoiscripts` → nothing.
- [ ] **Step 3: Commit** `feat(windows): user-scope Explorer and clock settings`.

### Task 5: Font, Windows Terminal, Python, WSL, SSH

**Files:**
- Modify: `home/.chezmoidata/font.yaml` (R14), `home/.chezmoiignore` (add `scoop/` to the non-Windows branch, R15)
- Move: WT settings to `home/scoop/persist/windows-terminal/settings/settings.json.tmpl` (`git mv`, content unchanged, R15)
- Delete: `run_once_before_install-font.ps1.tmpl`, `run_once_after_install-python.ps1` (R12)
- Modify (names kept): `run_once_before_install-wsl.ps1.tmpl` (R9), `run_once_after_add-ssh-key.ps1` (R10)
- Create: `scripts/admin/enable-developer-mode.ps1`, `scripts/admin/enable-wsl.ps1`, `scripts/admin/enable-ssh-agent.ps1` (R21)

- [ ] **Step 1: Font, terminal, Python** as listed.
- [ ] **Step 2: WSL and SSH scripts** with the exact skip messages from R9 and R10; WSL ranges over the view's `wsl`; `wsl.exe --status *> $null` then `$LASTEXITCODE`. Move the removed admin commands into the three `scripts/admin/` scripts per R21 (Developer Mode: compare before `Set-ItemProperty`, create the key if missing).
- [ ] **Step 3: Verify.** `chezmoi --source . managed` lists `scoop/persist/windows-terminal/settings/settings.json` and no `AppData/Local/Packages/...` and nothing under `scripts/`; render/parse check on the two user scripts and parse check on the three admin scripts → `errors=0`; `git grep -n -E "Set-Service|Start-Service|wsl(\.exe)? --update|AllowDevelopmentWithoutDevLicense" home` → nothing, the same grep on `scripts/admin` → one hit per command; `git grep -n "font\.name" home` → nothing.
- [ ] **Step 4: Commit** `feat(windows): Scoop font and terminal, admin commands moved out of apply`.

### Task 6: `install.ps1` bootstrap

**Files:** Modify `install.ps1` (R17).

- [ ] **Step 1: Rewrite** per R17 steps 1–4; keep `param`, the PATH refresh block and the final `chezmoi init --apply`. Elevation test on its own line: `$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)`, so the logic check can substitute it.
- [ ] **Step 2: Verify on the host** (nothing installed): 5.1 parse → `errors=0` (command from the #40 plan); `git grep -n -i "winget" install.ps1` → nothing; logic check on `powershell.exe` and `pwsh` in a temp file under the scratchpad with stand-ins `function scoop {}`, `function chezmoi {}`, `function Set-ExecutionPolicy {}`, `function Invoke-RestMethod {}`: (a) the `$isAdmin = …` line replaced by `$isAdmin = $true` and no `scoop` command → throws the R17 elevation message; (b) `Get-Command` stand-in reporting `pwsh` missing → throws `Installing 'pwsh' with Scoop failed…`; (c) all present → reaches `chezmoi`.
- [ ] **Step 3: Commit and push** `feat(install): bootstrap with Scoop without admin rights` (the VM downloads `install.ps1` from GitHub).

### Task 7: VM install test

**Files:** Modify `tests/windows/Installed-Apps-Modules.Tests.ps1` (R19).

- [ ] **Step 1: Rewrite** with the view from the Task 1 helper pattern in `BeforeDiscovery`; `BeforeAll`: `$installedApps = (scoop list).Name`, `$installedModules = (Get-InstalledModule).Name`, `$installedTools` as in Task 3; contexts `Apps` (`($_ -split '/')[-1]`), `Modules`, `.NET tools`, each `It "should have installed <_>" -ForEach`.
- [ ] **Step 2: Verify discovery on the host** (pass/fail is meaningless there, only the test count matters): `pwsh -NoProfile -Command 'Import-Module Pester -MinimumVersion 6.0.0; (Invoke-Pester tests/windows/Installed-Apps-Modules.Tests.ps1 -PassThru -Output None).TotalCount'` → `57` (39 + 6 + 12; results on the host are irrelevant).
- [ ] **Step 3: Commit** `test(windows): check Scoop apps, modules and .NET tools from the package view`.

### Task 8: Docs and VM acceptance

**Files:** Modify `docs/packages.md`, `docs/architecture.md`, `docs/chezmoi.md`, `docs/conventions.md`, `docs/testing.md`, `AGENTS.md`, `ReadMe.md` (prose lines 5 and 47), `.claude/agents/docs-sync.md` (R20, D1).

- [ ] **Step 1: Docs** per R20. AGENTS.md command row replacing the DSC drift row: `| Package view the scripts read | '{{ includeTemplate "packages.tmpl" . }}' \| chezmoi --source . execute-template |`. docs-sync agent §3: rows from every method list under `packages.global.profiles.*` and `packages.windows.profiles.*`; Install Type `App` (scoop), `Module`, `Tool`, `Yazi plugin`, `WSL distro`; Category = profile (D1), order by profile `base, shell, sdk, apps, ai`, then method, then YAML order; id in Name is the Scoop entry with bucket.
- [ ] **Step 2: Regenerate the README table** with the `docs-sync` agent; check `Reported: none`.
- [ ] **Step 3: Grep acceptance** (spec Acceptance 2) → nothing outside the allowed files.
- [ ] **Step 4: VM acceptance (owner-run, standard user created by hand):** spec Acceptance 3–5. For 5, add `nonexistent-app-43` to `base.scoop` in the synced working copy, apply, expect the summary and exit 1, revert. Record results, including the unverified items in spec *Risks*, on the PR.
- [ ] **Step 5: Commit** `docs: Scoop-based Windows setup` with `Fixes #43` and `Fixes #9`.

## Self-review

- Spec coverage: R1–R3, R12 (DSC part), R13, R16, R18, D2 → T1; R4, R5, R11 → T2; R6, R7 → T3; R8 → T4; R9, R10, R12 (font/Python), R14, R15, R21, D3 → T5; R17 → T6; R19, D4 → T7; R20, D1 → T8; Acceptance 1 → T1–T7 verify steps, 2–5 → T8.
- Unverified until the VM: `scoop list` fields, `wsl --status` exit code, `.dotnet\tools` on `PATH`, Explorer restart under a standard user.
