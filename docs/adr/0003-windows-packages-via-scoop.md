# ADR-0003: Install Windows software in user scope with Scoop

- **Status:** Accepted
- **Date:** 2026-11-19
- **Decider:** repository owner
- **Supersedes:** [ADR-0001](0001-windows-packages-via-dsc-v3.md)

## Context

ADR-0001 built Windows setup on a model that worked well: one declarative list in `packages.yaml`, rendered by
chezmoi into an install step that reruns when the list changes, with the profile, tests and docs derived from the
same list. Its engine, DSC v3 driving winget, carried one hidden assumption: **the person running setup is an
administrator.** winget installs most packages machine-wide, and the DSC resources write to `AllUsers` and `HKLM`.

That assumption no longer holds. The repo must also set up a machine where the user is a standard user. There,
setup did not partially work; it did not run at all. The problem is in the privilege model, not in a few packages,
so it cannot be fixed package by package.

## Decision

**Windows software is installed in user scope, with Scoop as the package manager. Setup runs entirely without admin
rights. Everything that needs machine-level rights is separated into an explicit privileged layer that an
administrator runs on its own.**

The architecture keeps ADR-0001's model and replaces only the engine underneath it:

| Kept from ADR-0001 | Changed |
|---|---|
| `packages.yaml` is the single source of truth | Install scope: machine → **user** (`%USERPROFILE%\scoop`, `CurrentUser`, `HKCU`) |
| chezmoi renders the install step from the list; `run_onchange` reruns it when the list changes | Engine: DSC configuration document → a rendered script calling Scoop and native user-scope commands |
| Every consumer (install, profile, tests, docs) derives from the same list | Privilege: one elevated run → **unprivileged apply + separate privileged layer** |
| Updates are the package manager's job; no version pins in the repo | Package manager for apps: winget → Scoop |
| Re-running setup is safe and installs only what is missing | DSC is removed entirely |

### The list

`packages.yaml` is grouped by platform, then by profile, then by install method (`scoop`, `modules`,
`dotnet_tools`, …). Items common to every platform sit under `global`. Each consumer reads the list directly: a
template ranges over the profiles of the platform it needs and renders one command per item. The install step, the
profile, the tests and the docs read the same data, so they depend on what is declared, not on how or by which
engine it is installed. How profiles are selected is a separate decision.

### The privilege boundary

The central decision is a boundary between two layers that differ in nature:

- **Unprivileged layer — `chezmoi apply`.** Everything that can live in the user profile: applications (Scoop),
  PowerShell modules (`-Scope CurrentUser`), .NET global tools, user settings (`HKCU`), config files. This layer
  always completes as a standard user, with no UAC prompt. The bootstrap that precedes it is unprivileged too:
  `install.ps1` sets the execution policy for the current user, installs Scoop, then git, chezmoi and PowerShell 7
  from Scoop, and hands over to `chezmoi init --apply`. No step of the chain asks for elevation.
- **Privileged layer — admin scripts.** The few things that are machine-level by nature: Developer Mode, Windows
  features such as WSL, system services such as `ssh-agent`. chezmoi deploys them as explicit scripts to
  `~/.config/dotfiles/admin/` but never runs them; the owner runs them elevated on a private machine, or an IT
  administrator runs them on a managed one.

The boundary follows the nature of each step, not who runs it. An administrator on a managed machine elevates with
their own account, so anything per user done in that session (a WSL distro, a key loaded into `ssh-agent`) would
land in the administrator's profile. The admin scripts therefore change only the machine and end by printing the
per-user step, which the user runs without admin rights.

The unprivileged layer does not depend on the privileged one to succeed. A step that needs a machine-level
prerequisite tries once during apply and, when the prerequisite is absent, skips with a one-line message that it needs
an administrator. After that, the admin script and the printed per-user step complete the work; no second apply is
needed.

### Why Scoop

Scoop is user-scope by design: it installs into the user profile and needs no elevation; its installer refuses to
run elevated by default. It provides every application the setup needs, including the Nerd Font, which ADR-0001
had to download through a separate script. Its install command is idempotent, so the generated script stays a flat
list of `scoop install` lines instead of an engine with resources.

ADR-0001 rejected Scoop partly because winget has a broader catalog and ships with Windows. The broader catalog
matters only for packages this setup does not use. Shipping with Windows saves one bootstrap step but does not help
when the packages it installs require admin rights. Neither outweighs a setup that runs without them.

DSC added value as a convergence engine for an admin-run machine. With the machine-level settings moved to the
privileged layer, what remains in user scope is a handful of `HKCU` values and two "install if missing" loops. That
is not worth an engine and its prerelease resource modules.

## Consequences

- **Setup runs where it could not run before.** One source and one install path serve both the private machine and
  a managed work machine, without asking for admin rights.
- **Privilege becomes explicit and minimal.** The few machine-level changes are named, separate, and auditable; on a
  managed machine they can be handed to IT as a short, reviewable script instead of a blanket "run as administrator".
- **Simpler stack.** No DSC engine, no prerelease resource modules, no pre-engine bootstrap, no per-tool download
  scripts. Install logic is a readable list of package-manager commands rendered from data.
- **The model survives the engine change.** Because consumers depend on the list, not on the engine, replacing
  winget + DSC with Scoop does not change how software is declared, how the profile and tests read it, or how
  updates are handled. The same property will let a future engine change stay local.
- **The admin scripts sit in a user-writable location.** An administrator runs them elevated from the user's
  profile with their own PowerShell 7, so they read the script before running it; the scripts are kept short for
  that reason. A managed fleet that cannot accept this copies them to an admin-only location first.
- **Bucket choice is a trust decision.** Scoop manifests come from bucket repositories, some community-maintained.
  Adding a bucket is reviewed like adding a dependency.
- **Drift is detected by comparing the declared list with what Scoop reports** instead of a DSC test run; removing
  an item from the list still does not uninstall it, as in ADR-0001.

## When to revisit

- A managed machine blocks execution from the user profile (AppLocker / WDAC), which removes the user-scope premise.
- A bucket used here is abandoned or compromised.
- A cross-platform mechanism could drive Windows and Linux from the same list.
