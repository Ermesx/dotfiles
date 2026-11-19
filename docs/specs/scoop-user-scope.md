# Spec: Windows setup installs everything in user scope with Scoop

Issue: [#43](https://github.com/Ermesx/dotfiles/issues/43) · ADR: [ADR-0003](../adr/0003-windows-packages-via-scoop.md) ·
Status: Draft · Date: 2026-11-19 · Plan: [`scoop-user-scope.plan.md`](scoop-user-scope.plan.md)

The issue fixes the decisions (Scoop for all apps, DSC removed, target `packages.yaml`, no uninstall, no state
file, no `scoop import`, no render-time `scoop list`). This spec turns them into requirements and adds what the
issue leaves open or gets wrong after reading the code (marked **[added]**).

## Decisions (confirmed 2026-11-19)

| # | Decision | Agreed | Why |
|---|---|---|---|
| D1 | README table *Category* column under the new schema | **The profile name** (`base`, `shell`, `sdk`, `apps`, `ai`); YAML comments become free-form notes; the category glossary in `docs/packages.md` is replaced by a profile glossary | The issue's target YAML has glossary comments only in `shell`; profiles are now the grouping dimension, so one key, one meaning |
| D2 | Acceptance "no reference to winget/DSC" vs `check-updates.ps1.tmpl` | `check-updates.ps1.tmpl` only switches to the view here and keeps its winget logic until #45; the grep criterion excludes that file and the accepted ADR-0002 (an accepted ADR is never edited) | The issue itself defers the rewrite to #45 |
| D3 | Admin-only commands removed from apply | **Parked, not dropped:** each goes unchanged in purpose into its own script in `scripts/admin/` (the layout #44 fixes); chezmoi never runs them. The user-side WSL/SSH scripts keep their `run_once_` names; making them retry after an admin run is #44's scope | `chezmoi apply` stays admin-free without losing Developer Mode, the WSL platform or the ssh-agent service |
| D4 | How the VM test reads the expected list | `chezmoi execute-template` of the view, no file deployed to `$HOME` | Replaces `~/.config/config.dsc.yaml`, which existed only for the test |
| D5 | .NET SDK | `main/dotnet-sdk`, always the latest; no pin | Following the latest SDK is a benefit of Scoop (winget needed a major-version id) |

## Requirements

### Data and view

- **R1** `home/.chezmoidata/packages.yaml` is exactly the target file from #43 (platform → profile → method,
  `pick`, `global`). Linux content is data only; no Linux script changes.
- **R2** `home/.chezmoitemplates/packages.tmpl` renders a JSON object: for `global` and then `.chezmoi.os`, for
  every profile (alphabetical, Go template map order), every key except `pick` is a method whose list is appended to
  the method's list in the view. Consumers use `includeTemplate "packages.tmpl" . | fromJson`. A missing method
  yields no key (consumers `range` over nil safely). `pick` is ignored until #20.
- **R3** Every consumer reads the view, never `.packages.*` directly: the profile module imports, `check-updates`
  (D2), the yazi plugins script, the install scripts, the WSL script, the tests.

### Install steps (all in `home/.chezmoiscripts/windows/`, run by `pwsh -NoProfile`)

- **R4 [added]** `home/.chezmoitemplates/refresh-env.ps1` copies every `User` environment variable into the
  process and sets `PATH` to `User;Machine`. Every script that calls a tool installed by Scoop in the same apply
  includes it (`{{ template "refresh-env.ps1" . }}`): the scoop, .NET tools and yazi scripts. Reason: Scoop sets
  `PATH` and `env_set` variables (`DOTNET_ROOT`, `MSBuildSDKsPath`) in the user registry, which chezmoi's process
  does not see.
- **R5** `run_onchange_before_01-scoop.ps1.tmpl`: renders the bucket list (unique `bucket/` prefixes) and the app
  list from the view. Adds buckets missing from `scoop bucket list`, then runs `scoop install <app>` once per app
  with Scoop's output visible. Afterwards reads `scoop list` once; an app is failed when its name (part after `/`)
  is absent or its `Info` contains `failed`. A failed `bucket add` is failed too. Prints `► …` progress, then a
  summary of failures, each with the hint `scoop uninstall <app>` then `chezmoi apply` (clears Scoop's failed
  state); exits 1 if anything failed, otherwise 0. One failure never stops the others.
- **R6** `run_onchange_before_02-modules.ps1.tmpl`: trusts PSGallery for the current user if not trusted; installs
  each view module absent from `Get-InstalledModule` with `Install-Module -Scope CurrentUser`. **[added]**
  `Get-InstalledModule`, not `Get-Module -ListAvailable`: the inbox Pester 3.4 would otherwise count as installed.
  `Pester` alone gets `-SkipPublisherCheck` (the inbox copy has a different publisher; without it the install
  throws). Failures collected, summary, exit 1 as in R5.
- **R7** `run_onchange_before_03-dotnet-tools.ps1.tmpl`: includes R4; installs each view tool absent from the first
  column of `dotnet tool list -g` (case-insensitive) with `dotnet tool install -g`; `$LASTEXITCODE` decides.
  Failures as in R5.
- **R8** `run_onchange_after_user-settings.ps1` (no template): under
  `HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced` sets DWORD `HideFileExt=0`, `Hidden=1`,
  `ShowSecondsInSystemClock=1` only where the value differs; restarts Explorer (`Stop-Process -Name explorer`,
  errors ignored) only if a value changed.
- **R9** `run_once_before_install-wsl.ps1.tmpl` (name kept, D3): sets
  `WSL_UTF8=1` **[added: `wsl -l -q` is UTF-16 otherwise and `-contains` never matches]**; if `wsl.exe --status`
  exits non-zero, prints `► Skipping WSL distro: WSL is not enabled (needs an administrator)` and exits 0; otherwise
  installs each view `wsl` distro missing from `wsl.exe -l -q` with `wsl.exe --install -d <distro> --no-launch`
  **[added: `--no-launch` keeps the first-run user prompt from blocking apply]**. No `wsl --update`.
- **R10** `run_once_after_add-ssh-key.ps1` (name kept, D3): if the `ssh-agent` service is
  not `Running`, prints `► Skipping SSH key: ssh-agent service is not running (needs an administrator)` and exits 0;
  otherwise runs `ssh-add` only when the key's fingerprint (`ssh-keygen -lf <key>.pub`, second field) is absent from
  `ssh-add -l`. No `Set-Service` / `Start-Service`.
- **R11** `run_once_after_yazi-plugins.ps1.tmpl` reads `yazi_plugins` from the view and includes R4.

### Files, font, terminal, profile

- **R12** Removed: `home/.chezmoitemplates/config.dsc.yaml.tmpl`, `home/dot_config/config.dsc.yaml.tmpl` and its
  line in `home/dot_config/.chezmoiignore` **[added]**, `run_once_before_00-pre-dsc.ps1`,
  `run_onchange_before_01-dsc.ps1.tmpl`, `run_once_before_install-font.ps1.tmpl`,
  `run_once_after_install-python.ps1`.
- **R13 [added]** `home/dot_profile/completers_profile.ps1.tmpl` drops the `dsc` and `winget` completers (`dsc` is no
  longer installed; the profile would print an error on every start).
- **R14** `font.yaml` keeps only `font.exactName: Hasklug Nerd Font`.
- **R15** Windows Terminal settings move unchanged from
  `home/readonly_AppData/Local/Packages/Microsoft.WindowsTerminal_8wekyb3d8bbwe/LocalState/settings.json.tmpl` to
  `home/scoop/persist/windows-terminal/settings/settings.json.tmpl` (assumes the default Scoop root `~\scoop`).
  `scoop/` is added to the non-Windows branch of `home/.chezmoiignore`.
- **R16** The profile imports every module of the view's `modules`.

### Parked admin commands (D3)

- **R21** `scripts/admin/` at the repo root (outside `home/`, never run by chezmoi), one script per item, with the
  commands #44 specifies; each idempotent, non-interactive, no elevation check, `► …` progress line:
  - `enable-developer-mode.ps1`: `HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock`
    `AllowDevelopmentWithoutDevLicense = 1` (DWORD), replacing the DSC `DeveloperMode` resource.
  - `enable-wsl.ps1`: `wsl.exe --install --no-distribution`, then `wsl.exe --update` (replaces the `wsl --update`
    removed from R9); prints that a reboot may be needed.
  - `enable-ssh-agent.ps1`: `Set-Service ssh-agent -StartupType Automatic`, `Start-Service ssh-agent` (removed
    from R10).
  The aggregate `admin-setup.ps1`, the end-of-apply reminder, retrying the user-side steps and their docs stay in #44.

### Bootstrap

- **R17** `install.ps1` (Windows PowerShell 5.1 and 7; `throw`, never `exit`; no PS 7-only syntax):
  1. If the `CurrentUser` execution policy is not `RemoteSigned`, `Unrestricted` or `Bypass`, set `RemoteSigned`
     for `CurrentUser`.
  2. If `scoop` is missing: **[added]** if the session is elevated, throw
     `Run install.ps1 from a non-elevated shell: Scoop installs per user and refuses to run as administrator.`
     (the Scoop installer's own refusal does not stop an `iex` caller cleanly); else install Scoop with
     `irm get.scoop.sh | iex`.
  3. `scoop install git chezmoi pwsh`, refresh `PATH` (as today), then for each of the three commands missing from
     `Get-Command` throw `Installing '<app>' with Scoop failed, run 'scoop install <app>' to see the details`.
  4. `chezmoi init --apply $GITHUB_USERNAME`.
  The winget bootstrap and the `$wingetCodes` map from #40 are removed.

### Tests and docs

- **R18** `tests/windows/Package-View.Tests.ps1` **[added]** (host and VM): renders the view (with `--source <repo>`
  when `.chezmoiroot` exists two levels up, else chezmoi's default source) and checks: keys are exactly `scoop`,
  `modules`, `wsl`, `dotnet_tools`, `yazi_plugins`; no `pick`; `scoop` has 39 items including
  `extras/windows-terminal` and `nerd-fonts/Hasklig-NF`; `modules` has the 6 modules and no
  `Microsoft.WinGet.Client`; `dotnet_tools` has 12; `wsl` is `Ubuntu-24.04`.
- **R19** `tests/windows/Installed-Apps-Modules.Tests.ps1` reads the view as in R18 and checks every Scoop app
  against `(scoop list).Name`, every module against `Get-InstalledModule`, every .NET tool against
  `dotnet tool list -g`.
- **R20** Docs: `docs/packages.md` (schema, methods, `[bucket/]app` verified with `scoop info`, D1, "new bucket is a
  trust decision"), `docs/architecture.md`, `docs/chezmoi.md`, `docs/conventions.md`, `docs/testing.md`,
  `AGENTS.md` (intro, the update rule → Scoop, the DSC drift row → a "package view" row), `ReadMe.md` prose,
  `.claude/agents/docs-sync.md` (new keys, D1), then the docs-sync agent regenerates the table.

## Non-goals

The admin aggregate script, reminder and user-step retry (#44), profile selection (#20), Check-Updates rewrite (#45), migrating a winget
machine (#46), CI and a provisioned standard user in Vagrant (#47), container engine (#48), GPG keys (#49), Linux
scripts (#12). No uninstall, no state file, no version pins.

## Acceptance

1. Host: `Package-View.Tests.ps1` passes; every changed `.ps1.tmpl` renders with `chezmoi --source . execute-template`
   and parses with zero errors; `install.ps1` parses on 5.1; `chezmoi --source . managed` succeeds; new `.ps1*`
   files are CRLF.
2. `git grep -n -i -E "winget|dsc|font\.name"` outside `docs/adr/0001-*` to `0003-*`, closed specs, this spec,
   `check-updates.ps1.tmpl` (D2) and the stock `DscResourcesToExport` comment in `Write-Pretty.psd1` returns nothing.
3. VM, **standard user** created by hand: `install.ps1` → apply finishes with exit 0, no UAC prompt; WSL and SSH
   steps print their skip messages; `Installed-Apps-Modules.Tests.ps1` passes; Windows Terminal starts with the
   managed settings and Hasklug Nerd Font; `dotnet ef --version` works in a new shell. In an elevated shell each
   `scripts/admin/*.ps1` runs twice without error, and the second run changes nothing.
4. Second apply runs none of the `run_onchange_` scripts; adding one app installs only that app.
5. Adding a non-existent app (`nonexistent-app-43`) yields a summary naming it and a non-zero exit; the other apps
   install.

## Risks

- `scoop list` field names (`Name`, `Info`) and the `failed` marker are read from Scoop's source, not observed; the
  VM failure path (Acceptance 5) confirms them.
- `wsl.exe --status` exit code without WSL enabled is unverified; confirm on the VM.
- Whether `~\.dotnet\tools` lands on `PATH` with the Scoop SDK is unverified (Acceptance 3).
- A `before_` script failure aborts chezmoi before files are written. Accepted: `run_onchange_` retries on the next
  apply, and the summary says what to fix.
