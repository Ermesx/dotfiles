# Spec: Rancher Desktop instead of Docker Desktop

Issue: [#48](https://github.com/Ermesx/dotfiles/issues/48) · ADR: [ADR-0004](../adr/0004-container-engine.md) ·
Status: Draft · Date: 2026-11-24 · Plan: [`container-engine.plan.md`](container-engine.plan.md) · PR: #58

## Goal

After installing the dotfiles, a Linux container engine is available that `docker`, `docker compose`, `docker buildx`
and Docker API clients (Testcontainers, Aspire, IDEs) reach on the default endpoint `\\.\pipe\docker_engine` with no
configuration once it runs. It replaces Docker Desktop with the fewest components to install and maintain, without
admin rights.

Aspire and Testcontainers are the usage that sets the bar, not part of this repo: an Aspire AppHost runs .NET
projects (including .NET Framework 4.8) as host processes and only dependencies (PostgreSQL, Kafka, RabbitMQ, …) as
containers, all Linux images. So one Linux engine with the Docker API covers the goal.

## Decisions (2026-11-24)

| # | Question | Agreed | Rejected alternative and why |
|---|---|---|---|
| D1 | Windows containers | **Out of scope** | An optional admin script with `dockerd.exe` as a service on its own pipe (built, then removed): Aspire does not support Windows containers ([microsoft/aspire#8063](https://github.com/microsoft/aspire/issues/8063)), .NET Framework apps run on the host, and Windows-only dependencies (MSMQ, SSRS, .NET Framework images for prod parity) are niche — handled when one appears |
| D2 | Engine | **Rancher Desktop, moby** (`extras/rancher-desktop`) | `dockerd` in my WSL distro via shell commands: six pieces of glue to own (F7); Docker Desktop: license, machine-wide; Podman: emulated Docker API (Testcontainers, BuildKit); `wslc`: no Docker Engine API ([microsoft/WSL#40976](https://github.com/microsoft/WSL/issues/40976)) |
| D3 | Docker clients | **Rancher's bundled copies only** | Keep Scoop `docker`, `docker-compose`, `docker-buildx`: never run (F4), and `main/docker` adds a `dockerd` shim to PATH |
| D4 | Profile | **New `containers`, no `pick`**, skipped in CI | `sdk`: CI skips apps per profile (`ci.skip_scoop_profiles`), so Rancher there means ~711 MB on every push for an engine the runner cannot run; skipping single apps would be a new mechanism. `apps` with `pick` (the issue's proposal): Rancher is the only docker CLI, an optional pick would leave a machine without `docker`. The profile also groups what only makes sense together (engine, `lazydocker`, `DockerCompletion`) |
| D5 | First-run configuration | **`create_` seed of `settings.json` with three keys** (table below) | Rancher's defaults: Kubernetes on and a first-run dialog. Deployment profile under `HKCU\Software\Policies`: not writable by a standard user (F3). `rdctl set` after start: Kubernetes already starting |
| D6 | When the engine runs | **On demand**: I start Rancher when I need containers | Start at login: memory and CPU spent when no container is needed |
| D7 | Updates | **Rancher updates itself** (its updater stays on); Scoop installs it | Updater off so that only Scoop updates (ADR-0003): rejected by the owner; this is a deliberate exception, with risk R-1 |
| D8 | Docker context | **None managed**; nothing runs `docker context use` | Testcontainers follows `currentContext` in `~/.docker/config.json`; a switched context redirects every test |
| D9 | Profile without `containers` | **The PowerShell profile imports only the modules of installed profiles**, by the same rule as the Scoop install (today: with `CI=true`, not `ci.skip_scoop_profiles`) | Runtime guard `if (Get-Command docker)` around the import: reacts to machine state instead of the declaration, a special case for one profile, and not testable statically. Unconditional import: loads docker tooling where `containers` was not installed, and fails once #20 can leave the module uninstalled |

### The seed (D5)

| Key | Value | Rancher default | Why |
|---|---|---|---|
| `version` | 19 | — | required in every `settings.json`; Rancher 1.25 refuses to start without it (F2) |
| `kubernetes.enabled` | false | **true** | k3s would start with every engine start: memory, CPU and start-up time for nothing a Docker user needs |
| `containerEngine.name` | `moby` | moby | explicit: real `dockerd`, which Testcontainers needs; safe against a changed default |

An existing file also skips the first-run dialog. Without the seed Rancher still works; I would untick Kubernetes in
that dialog once per machine.

## Facts (verified 2026-11-24, Rancher Desktop 1.25.0)

| # | Fact | Source |
|---|---|---|
| F1 | Scoop `extras/rancher-desktop` 1.25.0 extracts the MSI per user (no admin) and adds `resources\resources\win32\bin` and `…\linux\bin` to PATH | [manifest](https://github.com/ScoopInstaller/Extras/blob/master/bucket/rancher-desktop.json) |
| F2 | Settings live in `%LOCALAPPDATA%\rancher-desktop\settings.json`. A partial file is completed with defaults; **`version` is required** (current: 19) or Rancher refuses to start; Rancher rewrites the file on every start; an existing file skips the first-run dialog | `rdctl/pkg/paths/paths_windows.go`, `config/settingsImpl.ts`, `config/settings.ts` at v1.25.0 |
| F3 | Deployment profiles are read from `HK{LM,CU}\Software\Policies\Rancher Desktop`; a standard user has only read access to `HKCU\Software\Policies`. An HKLM profile makes Rancher ignore the HKCU one | [deployment docs](https://docs.rancherdesktop.io/getting-started/deployment), `Get-Acl` on the host |
| F4 | Rancher ships `docker.exe` (in `win32\bin`) and `docker-compose.exe`, `docker-buildx.exe` (in `win32\docker-cli-plugins`, appended to `cliPluginsExtraDirs` in `~/.docker/config.json`). Scoop prepends its PATH entries, so Rancher's `docker` wins; extra plugin dirs are searched before `~/.docker/cli-plugins` | Scoop `lib/system.ps1`, Rancher `scripts/dependencies/tools.ts`, docker/cli `cli-plugins/manager` |
| F5 | The engine listens on `\\.\pipe\docker_engine` (hard-coded); no docker context is created on Windows; published ports are reachable on `localhost`; Windows CA certificates are imported into the engine's distro on every start | Rancher `serve_windows.go`, `dockerDirManager.ts`, `wsl.ts` |
| F6 | Defaults: `containerEngine.name` `moby`, `kubernetes.enabled` true, `application.updater.enabled` true, `application.autoStart` false | `config/settings.ts` at v1.25.0 |
| F7 | Plain `dockerd` in WSL would need: docker-ce in the distro, a TCP or pipe bridge, `DOCKER_HOST`, keeping WSL alive (systemd services do not; a distro stops 15 s after its last process, `instanceIdleTimeout`), start at login, Windows CLI and plugins, CA import, `apt` updates outside `Update-Apps` | [WSL config](https://learn.microsoft.com/windows/wsl/wsl-config), [WSL systemd](https://learn.microsoft.com/windows/wsl/systemd) |
| F8 | `Update-Apps` keeps going when one app fails; Scoop skips an app with a running process and exits 0, and `Update-Apps` then reports it as `Not updated: … close its running instances`. Apps declared but not installed are not listed (`scoop status --local`) | `PackageUpdates/public/Update-Apps.ps1`, `private/Invoke-PackageUpdateLoop.ps1`, `private/Get-ScoopAppUpdates.ps1` |

## Requirements

### Packages

- **R1** `home/.chezmoidata/packages.yaml`: profile `windows.profiles.containers` = `scoop: [extras/rancher-desktop,
  lazydocker]`, `modules: [DockerCompletion]`, no `pick`. Removed from `windows.profiles.sdk`: `docker`,
  `docker-compose`, `docker-buildx` (replaced by Rancher's copies, D3), `lazydocker`, `DockerCompletion` (moved).
  Linux `sdk.brew: [docker]` unchanged (#12).
- **R2** No `windows` profile declares `docker`, `docker-compose` or `docker-buildx` (one docker CLI).
- **R3** `home/.chezmoidata/ci.yaml`: `skip_scoop_profiles: [apps, containers]`. With `CI=true` the rendered Scoop
  script installs neither `extras/rancher-desktop` nor `lazydocker`; without `CI` it installs both.

### Settings seed

- **R4** `home/readonly_AppData/Local/rancher-desktop/create_settings.json` (target
  `AppData/Local/rancher-desktop/settings.json`, created only when missing) contains exactly `version` 19,
  `containerEngine.name` `"moby"`, `kubernetes.enabled` false — and no `application` key (D6, D7). Valid JSON, LF.
- **R5** chezmoi manages neither `~/.docker/config.json` nor anything under `~/.docker/contexts` (D8; Rancher edits
  the config file, F4).

### Profile

- **R10** `home/readonly_Documents/PowerShell/Microsoft.PowerShell_profile.ps1.tmpl` renders `Import-Module` only for
  the profiles that are installed, with the same rule and data as `run_onchange_before_01-scoop.ps1.tmpl`: with
  `CI=true`, the profiles in `ci.skip_scoop_profiles` are left out. With `CI=true` the rendered profile has no
  `DockerCompletion` and still `posh-git`; without `CI` it imports `DockerCompletion`. The rendered profile parses.
  Profile selection (#20) extends the same rule.

### Docs and tests

- **R6** ADR-0004: context, decision, options compared by what is installed and maintained, consequences.
- **R7** `docs/packages.md` profile glossary has `containers`; `sdk` no longer mentions container clients.
- **R8** `.claude/agents/docs-sync.md` profile list and order: `base`, `shell`, `sdk`, `containers`, `apps`, `ai`;
  `ReadMe.md` package table regenerated by `docs-sync` (Rancher Desktop, lazydocker, DockerCompletion under
  `containers`; the three docker clients gone).
- **R11** Static tests pin R2, R3, R4, R5, R8 and R10: `tests/static/ContainerEngine.Tests.ps1`, two cases in
  `tests/static/CiProfiles.Tests.ps1`.

### Migration (recorded in #46, not automated)

- **R9** Before the first apply with this change: save needed images (`docker save`) and volume data, quit and
  uninstall Docker Desktop (it also binds `docker_engine`). After apply: `scoop uninstall docker docker-compose
  docker-buildx` (also on the work laptop, which got them from #43), delete `docker-compose.exe` and
  `docker-buildx.exe` from `~/.docker/cli-plugins`, restore images and volumes.

## Acceptance (real machine, standard user; not verifiable on the host or in CI)

- [ ] **A1** After apply, Rancher does **not** start by itself. Started from the Start menu: no first-run dialog;
  `rdctl list-settings | ConvertFrom-Json` shows `containerEngine.name` `moby`, `kubernetes.enabled` False.
- [ ] **A2** `(Get-Command docker -All).Source` lists only `…\rancher-desktop\…\win32\bin\docker.exe`;
  `docker compose version` and `docker buildx version` work.
- [ ] **A3** `docker run --rm hello-world` and `docker compose up -d` with `nginx` on `8080:80` work;
  `Invoke-WebRequest http://localhost:8080` returns 200.
- [ ] **A4** A Testcontainers for .NET test (`Testcontainers.PostgreSql`) passes with Rancher running and no
  `DOCKER_HOST` set.
- [ ] **A5 (R-1)** After Rancher's own update: `(Get-Command docker -All).Source` and `$env:LOCALAPPDATA\Programs`
  show whether a second copy appeared; `scoop list rancher-desktop` shows which version Scoop has.
- [ ] **A6** `Update-Apps` with Rancher running: the other apps update; it ends with `Not updated: rancher-desktop …`.
- [ ] **A7** CI (`tests/windows/Profile.Tests.ps1` after apply with `containers` skipped): the profile loads with no
  error and does not import `DockerCompletion`.

## Risks

| Risk | Signal | Response |
|---|---|---|
| **R-1** Rancher's updater runs its MSI installer, which may install a second copy outside `~\scoop\apps\rancher-desktop` while Scoop keeps updating its own (D7) | A5 finds two copies or two `docker` on PATH | Decide then: Rancher from its installer only (out of Scoop), or updater off |
| Stale `cliPluginsExtraDirs` entries pile up across Rancher versions (Rancher only appends) | Old compose/buildx versions run | Clean `~/.docker/config.json` by hand |
| Aspire on Rancher is "community reported", with a reported port-mapping issue ([microsoft/aspire#10199](https://github.com/microsoft/aspire/issues/10199)) | Aspire resources unreachable | Fallback: Docker Desktop if a Docker Business license exists (ADR-0004) |
| A company HKLM deployment profile overrides settings (F3) | A1 shows other values | Accept the company's choice |
| Engine not running when a Docker API client starts (D6) | `docker` / tests fail to connect | Start Rancher first (Start menu or `rdctl start`) — accepted |

## Non-goals

Windows containers (D1); Kubernetes; the Linux side (#12); automating the migration (#46).
