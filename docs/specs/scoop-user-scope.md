# Spec: Windows setup installs everything in user scope with Scoop

Issue: [#43](https://github.com/Ermesx/dotfiles/issues/43) · ADR: [ADR-0003](../adr/0003-windows-packages-via-scoop.md) ·
Status: Draft · Date: 2026-11-19, revised 2026-11-20 after the PR #50 review · Plan: [`scoop-user-scope.plan.md`](scoop-user-scope.plan.md)

The issue fixes the decisions (Scoop for all apps, DSC removed, target `packages.yaml`, no uninstall, no state
file, no `scoop import`, no render-time `scoop list`). This spec turns them into requirements and adds what the
issue leaves open or gets wrong after reading the code (marked **[added]**). Requirements changed by the PR #50
review are marked **[revised]**: no shared package view, flat install scripts without result checks, admin
scripts deployed by chezmoi and limited to the machine part, the simple bootstrap.

## Decisions (confirmed 2026-11-19)

| # | Decision | Agreed | Why |
|---|---|---|---|
| D1 | README table *Category* column under the new schema | **The profile name** (`base`, `shell`, `sdk`, `apps`, `ai`); YAML comments become free-form notes; the category glossary in `docs/packages.md` is replaced by a profile glossary | The issue's target YAML has glossary comments only in `shell`; profiles are now the grouping dimension, so one key, one meaning |
| D2 | Acceptance "no reference to winget/DSC" vs `check-updates.ps1.tmpl` | `check-updates.ps1.tmpl` only switches its lists to `packages.yaml` here and keeps its winget logic until #45; the grep criterion excludes that file and the accepted ADR-0002 (an accepted ADR is never edited) | The issue itself defers the rewrite to #45 |
| D3 | Admin-only commands removed from apply | **Parked, not dropped [revised]:** each goes into its own script that chezmoi deploys to `~/.config/dotfiles/admin/` and never runs. A script changes only the machine and prints the per-user step (WSL distro, `ssh-add`): an administrator elevating with their own account would put those into their own profile. The user-side WSL/SSH scripts try once (`run_once_`); when the machine part is missing they skip with a one-line message that it needs an administrator | `chezmoi apply` stays admin-free without losing Developer Mode, the WSL platform or the ssh-agent service, and no second apply is needed after the admin step |
| D4 | How the VM test reads the expected list | `chezmoi data` **[revised]**, no file deployed to `$HOME` | Replaces `~/.config/config.dsc.yaml`, which existed only for the test |
| D5 | .NET SDK | `main/dotnet-sdk`, always the latest; no pin | Following the latest SDK is a benefit of Scoop (winget needed a major-version id) |

## Requirements

### Data

- **R1** `home/.chezmoidata/packages.yaml` is exactly the target file from #43 (platform → profile → method,
  `pick`, `global`). Linux content is data only; no Linux script changes.
- **R2 [revised]** No shared view. A consumer of a method ranges over `.packages.<platform>.profiles` (Go
  template map order, alphabetical) and reads the method with `get . "<method>" | default list`, because not every
  profile has every method; `pick` is never read, so it is ignored until #20.
- **R3 [revised]** Items in one place are read by path: `.packages.windows.profiles.sdk.wsl` (a scalar: one
  distro) and `.packages.global.profiles.shell.yazi_plugins`. Consumers: the profile module imports,
  `check-updates` (D2), the yazi plugins script, the install scripts, the WSL script and the admin WSL script.

### Install steps (all in `home/.chezmoiscripts/windows/`, run by `pwsh -NoProfile`)

- **R4 [revised]** Install scripts are flat: the template renders one command per item; no PowerShell loops, no
  result checks, no failure summary, no `exit 1`. The commands converge by themselves (installed items are skipped
  or only warned about); a failure shows in the output and in R19. Environment: each script is its own process with
  chezmoi's environment; Scoop shims are on `PATH` since `install.ps1`, so only a script that calls an app with
  `env_add_path`/`env_set` reads them back from the user registry (R7).
- **R5 [revised]** `run_onchange_before_01-scoop.ps1.tmpl`: `scoop bucket add <bucket>` for each unique `bucket/`
  prefix, then `scoop install <app>` for each app, with `► …` progress lines.
- **R6 [revised]** `run_onchange_before_02-modules.ps1.tmpl`: `Set-PSRepository PSGallery -InstallationPolicy
  Trusted`, then `Install-Module -Name <m> -Scope CurrentUser` per module. `Pester` alone gets `-Force
  -SkipPublisherCheck`: the inbox 3.4 has a different publisher, and without `-Force` the installed 3.4 blocks a
  side-by-side install.
- **R7 [revised]** `run_onchange_before_03-dotnet-tools.ps1.tmpl`: sets `PATH` to `User;Machine` and `DOTNET_ROOT`
  from the user registry (`dotnet-sdk` uses `env_add_path` and `env_set`), then `dotnet tool install -g <id>` per
  tool.
- **R8** `run_onchange_after_user-settings.ps1` (no template): under
  `HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced` sets DWORD `HideFileExt=0`, `Hidden=1`,
  `ShowSecondsInSystemClock=1` only where the value differs; restarts Explorer (`Stop-Process -Name explorer`,
  errors ignored) only if a value changed.
- **R9 [revised]** `run_once_before_install-wsl.ps1.tmpl` (one try, D3): sets `WSL_UTF8=1` **[added: `wsl -l -q`
  is UTF-16 otherwise and `-contains` never matches]**; checks `wsl --status` **before** any other `wsl` call; if it
  exits non-zero, prints one line `► Skipping WSL distro: WSL is not enabled (needs an administrator)` and exits 0
  (the admin script prints the per-user step); otherwise installs the distro when missing from `wsl -l -q` with
  `wsl --install -d <distro> --web-download --no-launch` (`--web-download` works where the Microsoft Store is
  blocked; `--no-launch` keeps the first-run prompt from blocking apply). No `wsl --update`.
- **R10 [revised]** `run_once_after_add-ssh-key.ps1` (one try, D3): if the `ssh-agent` service is not `Running`,
  prints one line `► Skipping SSH key: ssh-agent is not running (needs an administrator)` and exits 0; otherwise
  `ssh-add ~\.ssh\id_ed25519`. No fingerprint check, no
  `Set-Service` / `Start-Service`.
- **R11 [revised]** `run_once_after_yazi-plugins.ps1.tmpl` reads `.packages.global.profiles.shell.yazi_plugins`;
  `ya` is a Scoop shim, so no environment refresh.

### Files, font, terminal, profile

- **R12** Removed: `home/.chezmoitemplates/config.dsc.yaml.tmpl`, `home/dot_config/config.dsc.yaml.tmpl` and its
  line in `home/dot_config/.chezmoiignore` **[added]**, `run_once_before_00-pre-dsc.ps1`,
  `run_onchange_before_01-dsc.ps1.tmpl`, `run_once_before_install-font.ps1.tmpl`,
  `run_once_after_install-python.ps1`.
- **R13 [added, revised]** `home/dot_profile/completers_profile.ps1.tmpl` drops the `dsc` completer (`dsc` is no
  longer installed; the profile would print an error on every start). The `winget` completer stays: winget may
  still be used.
- **R14** `font.yaml` keeps only `font.exactName: Hasklug Nerd Font`.
- **R15** Windows Terminal settings move unchanged from
  `home/readonly_AppData/Local/Packages/Microsoft.WindowsTerminal_8wekyb3d8bbwe/LocalState/settings.json.tmpl` to
  `home/scoop/persist/windows-terminal/settings/settings.json.tmpl` (assumes the default Scoop root `~\scoop`).
  `scoop/` is added to the non-Windows branch of `home/.chezmoiignore`.
- **R16** The profile imports every module under `.packages.windows.profiles.*.modules`.

### Parked admin commands (D3)

- **R21 [revised]** `home/dot_config/dotfiles/admin/`, deployed to `~/.config/dotfiles/admin/` and never run by
  chezmoi (excluded on Linux by `**/*.ps1` in `home/.chezmoiignore`), one script per item; PowerShell 7, each
  idempotent, non-interactive, no elevation or identity check, `► …` progress line. A script changes only the
  machine and ends by printing the per-user step, which the user runs without admin:
  - `enable-developer-mode.ps1`: `HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock`
    `AllowDevelopmentWithoutDevLicense = 1` (DWORD), replacing the DSC `DeveloperMode` resource.
  - `enable-wsl.ps1.tmpl`: `wsl --install --no-distribution`, then `wsl --update` (removed from R9); prints: restart,
    then as the user `wsl --install -d <distro from packages.yaml> --web-download --no-launch`.
  - `enable-ssh-agent.ps1`: `Set-Service ssh-agent -StartupType Automatic`, `Start-Service ssh-agent` (removed
    from R10); prints: as the user `ssh-add $HOME\.ssh\id_ed25519`.
  Why the split: WSL distros are per user ("can't be shared with other Windows user accounts", MS Learn, WSL setup)
  and so are the agent's keys (`HKCU`); an administrator elevating with their own account would install both into
  their own profile. The aggregate `admin-setup.ps1`, the end-of-apply reminder and their docs stay in #44.

### Bootstrap

- **R17 [revised]** `install.ps1` keeps the shape of the winget version, with no extra guards (Windows
  PowerShell 5.1 and 7):
  1. `Set-ExecutionPolicy RemoteSigned -Scope CurrentUser -Force`.
  2. If `scoop` is missing, install it with `irm get.scoop.sh | iex` (the installer refuses an elevated shell).
  3. `scoop install git chezmoi pwsh`, refresh `PATH` (as before).
  4. `chezmoi init --apply $GITHUB_USERNAME`.
  The winget bootstrap and the `$wingetCodes` map from #40 are removed.

### Tests and docs

- **R18 [revised]** Removed with the view: there is no `Package-View.Tests.ps1`.
- **R19** `tests/windows/Installed-Apps-Modules.Tests.ps1` reads `chezmoi data` (with `--source <repo>` when
  `.chezmoiroot` exists two levels up, else chezmoi's default source) and checks every Scoop app (39) against
  `(scoop list).Name`, every module (6) against `Get-InstalledModule`, every .NET tool (12) against
  `dotnet tool list -g`.
- **R20** Docs: `docs/packages.md` (schema, methods, `[bucket/]app` verified with `scoop info`, D1, "new bucket is a
  trust decision"), `docs/architecture.md`, `docs/chezmoi.md`, `docs/conventions.md`, `docs/testing.md`,
  `AGENTS.md` (intro, the update rule → Scoop, the DSC drift row removed), `ReadMe.md` prose,
  `.claude/agents/docs-sync.md` (new keys, D1, column *Profile*), then the docs-sync agent regenerates the table.

## Non-goals

The admin aggregate script and reminder (#44), profile selection (#20), Check-Updates rewrite (#45), migrating a winget
machine (#46), CI and a provisioned standard user in Vagrant (#47), container engine (#48), GPG keys (#49,
dropped: signing uses SSH), Linux scripts (#12). No uninstall, no state file, no version pins.

## Acceptance

1. Host: every changed `.ps1.tmpl` renders with `chezmoi --source . execute-template` and parses with zero errors;
   `install.ps1` parses on 5.1; `chezmoi --source . managed` succeeds and lists `.config/dotfiles/admin/*.ps1`;
   `Installed-Apps-Modules.Tests.ps1` discovers 57 tests; new `.ps1*` files are CRLF.
2. `git grep -n -i -E "winget|dsc|font\.name"` outside `docs/adr/0001-*` to `0003-*`, closed specs, this spec and
   its plan, `check-updates.ps1.tmpl` (D2), the `winget` completer (R13) and the stock `DscResourcesToExport`
   comment in `Write-Pretty.psd1` returns nothing.
3. VM, **standard user** created by hand: `install.ps1` → apply finishes with exit 0, no UAC prompt; WSL and SSH
   steps print their skip messages; `Installed-Apps-Modules.Tests.ps1` passes; Windows Terminal starts with the
   managed settings and Hasklug Nerd Font; `dotnet ef --version` works in a new shell.
4. From a second, administrator account each script in `~/.config/dotfiles/admin/` runs twice without error through
   `pwsh -NoProfile -ExecutionPolicy Bypass -File <script>`, and the second run changes nothing. After
   the restart the standard user runs the printed `wsl --install …` and `ssh-add …` without admin; the distro
   starts and `ssh-add -l` lists the key.
5. Second apply runs none of the `run_onchange_` scripts; adding one app installs only that app.

## Risks

- `wsl --status` exit code without WSL enabled and with a restart pending is unverified; both must be non-zero.
  Confirm on the VM.
- Whether `~\.dotnet\tools` lands on `PATH` with the Scoop SDK is unverified (Acceptance 3).
- A failed install does not fail apply and is not retried until the list changes (accepted in the review); R19
  detects it, `scoop install <app>` fixes it by hand.
- The admin scripts live in the user's profile, which the user can write to; an administrator runs them elevated
  with their own `pwsh`, so they review the (short) script first. Accepted for a personal setup; see ADR-0003.
- `dotnet tool install -g` on an already installed tool may update it on recent SDKs instead of failing, which
  would make a list change also update the tools. Confirm on the VM; if so, accept it here or render a skip.
- `Install-Module` without `-Force` could prompt for the NuGet provider on a fresh profile; PowerShell 7 ships it
  with PackageManagement, so no prompt is expected. Confirm on the VM.
