# ADR-0004: Rancher Desktop instead of Docker Desktop

- **Status:** Accepted
- **Date:** 2026-11-24
- **Decider:** repository owner
- **Related:** [ADR-0003](0003-windows-packages-via-scoop.md), issue [#48](https://github.com/Ermesx/dotfiles/issues/48)

## Context

I need what Docker Desktop gave me: a Linux container engine that `docker`, compose and tools using the Docker API
(e.g. Testcontainers) reach on the default endpoint `\\.\pipe\docker_engine`, with no extra configuration. ADR-0003
dropped Docker Desktop (machine-wide install, own updater, paid license in larger companies). WSL is available.

## Decision

**Rancher Desktop with the moby engine, installed by Scoop, replaces Docker Desktop. It is the only engine and the
only docker CLI. Windows containers are out of scope.**

- `extras/rancher-desktop` (profile `containers`, with `lazydocker` and `DockerCompletion`): real `dockerd` in its own
  WSL distro, the default pipe, ports on `localhost`, corporate CA certificates imported from Windows. No admin.
- Its bundled `docker`, `docker-compose` and `docker-buildx` come first on PATH, so the Scoop copies are removed.
- chezmoi seeds `%LOCALAPPDATA%\rancher-desktop\settings.json` once: moby, Kubernetes off, updater off (Scoop
  updates), start at login in the background.

## Options considered

| Option | What I install and maintain | Why not |
|---|---|---|
| **Rancher Desktop** | one Scoop app, one settings file | — |
| `dockerd` in my WSL distro via shell commands | docker-ce in the distro, a TCP or pipe bridge, `DOCKER_HOST`, keeping WSL alive (systemd does not), start at login, CLI + plugins, CA import, `apt` updates | Six pieces of glue instead of two; revisit with the Linux side (#12) |
| Docker Desktop | one installer | License cost, machine-wide, own updater. Fallback if Rancher fails me and a license exists |
| Podman | `podman machine` | Emulated Docker API: Testcontainers and BuildKit issues |
| WSL containers (`wslc`) | nothing | No Docker Engine API |

## Consequences

- One `docker` on PATH; compose and buildx versions follow Rancher releases.
- Docker Desktop must be uninstalled before the first apply with this change (both use `docker_engine`); old Scoop
  clients are removed after it. Both steps are in the migration checklist (#46).
- Windows containers need a separate engine; add one only when a real need appears.
