# ADR-0004: Rancher Desktop instead of Docker Desktop

- **Status:** Accepted
- **Date:** 2026-11-24
- **Decider:** repository owner
- **Related:** [ADR-0003](0003-windows-packages-via-scoop.md), issue [#48](https://github.com/Ermesx/dotfiles/issues/48)

## Context

I need what Docker Desktop gave me: a Linux container engine that `docker`, compose and tools using the Docker API
(e.g. Testcontainers) reach on the default endpoint `\\.\pipe\docker_engine`, with no extra configuration. ADR-0003
dropped Docker Desktop (machine-wide install, paid license in larger companies). WSL is available.

## Decision

**Rancher Desktop with the moby engine, installed by Scoop, replaces Docker Desktop. It is the only engine and the
only docker CLI. Windows containers are out of scope.**

- `extras/rancher-desktop` (profile `containers`, with `lazydocker` and `DockerCompletion`): real `dockerd` in its own
  WSL distro, the default pipe, ports on `localhost`, corporate CA certificates imported from Windows. No admin.
- Its bundled `docker`, `docker-compose` and `docker-buildx` come first on PATH, so the Scoop copies are removed.
- chezmoi seeds `%LOCALAPPDATA%\rancher-desktop\settings.json` once with three keys: `version` (required, or Rancher
  does not start), moby, Kubernetes off (k3s would cost memory and start-up time on every start). The file also skips
  the first-run dialog; after that it belongs to Rancher.
- **Started on demand**, not at login: the engine costs memory, so I start Rancher when I need containers.
- **Rancher updates itself** (its updater stays on). This is a deliberate exception to "updates are Scoop's job"
  (ADR-0003): Scoop installs it, the application keeps itself current.
- The PowerShell profile imports only the modules of installed profiles (same rule as the Scoop install), so
  `DockerCompletion` is not imported where `containers` was skipped.

## Options considered

| Option | What I install and maintain | Why not |
|---|---|---|
| **Rancher Desktop** | one Scoop app, one settings file | — |
| `dockerd` in my WSL distro via shell commands | docker-ce in the distro, a TCP or pipe bridge, `DOCKER_HOST`, keeping WSL alive (systemd does not), start at login, CLI + plugins, CA import, `apt` updates | Six pieces of glue instead of two; revisit with the Linux side (#12) |
| Docker Desktop | one installer | License cost, machine-wide install. Fallback if Rancher fails me and a license exists |
| Podman | `podman machine` | Emulated Docker API: Testcontainers and BuildKit issues |
| WSL containers (`wslc`) | nothing | No Docker Engine API |

## Consequences

- One `docker` on PATH; compose and buildx versions follow Rancher releases.
- Docker Desktop must be uninstalled before the first apply with this change (both use `docker_engine`); old Scoop
  clients are removed after it. Both steps are in the migration checklist (#46).
- Without Rancher running, `docker` and Docker API clients fail; start it first (Start menu or `rdctl start`).
- Two update paths exist (Rancher's updater and Scoop's manifest). Whether the updater installs a second copy outside
  Scoop is unverified; if it does, Rancher moves out of Scoop.
- Windows containers need a separate engine; add one only when a real need appears.
