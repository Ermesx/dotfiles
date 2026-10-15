# ADR-0002: Manage dotfiles with chezmoi as the single cross-platform source

- **Status:** Accepted
- **Date:** 2025-08-31 (PR #4 `migration-to-chezmoi`, started in `41179e8`; recorded 2026-10-15)
- **Decider:** repository owner

## Context

The repo has kept configuration since 2014. Before this decision it was a `src/` tree with one folder per tool and
two hand-written build scripts:

- `build.ps1` / `build.sh` copied `src/` into `build/windows` or `build/linux`, choosing files by extension
  (`.ps1` vs `.sh`) and by the words `windows` / `linux` in the path. Per-tool `configure.ps1` scripts and the
  `Dotfiles-Toolkit` module then put files and software in place.
- OS selection was a naming convention, not a feature. There was no templating, so per-host or per-OS
  differences inside a file meant duplicating the file.
- There was no way to see what an update would change before running it, and no built-in secret handling.
- Updating a machine meant pulling the repo and re-running the build and configure scripts by hand.

Forces:

- One source must serve Windows (primary) and Linux (WSL and standalone), with per-OS differences inside files,
  not only per-file.
- Updating an existing machine must be one command and safe to repeat.
- Some files are secrets (SSH key, tokens) and must live in a public repo encrypted.
- Setup steps (installing software, fonts, WSL) must run in a defined order, and only when needed.
- The tool must run natively on Windows without WSL, Cygwin, or symlink privileges.

## Decision

Use **chezmoi** as the dotfiles manager and the orchestrator of machine setup, with this repo as its source.

- `home/` is the chezmoi source (`.chezmoiroot`). Everything outside it is repo tooling and is never applied.
- Per-OS and per-host differences use Go templates (`.chezmoi.os`, `env "VAGRANT"`) inside files, and
  `.chezmoiignore` files exclude whole files per OS.
- Shared data (package lists, font) lives in `home/.chezmoidata/` and feeds templates and scripts. ADR-0001 builds on
  this for Windows software.
- Setup steps are chezmoi scripts in `home/.chezmoiscripts/<os>/`: `run_once_` for one-time steps, `run_onchange_`
  for steps that must rerun when their inputs change, and numeric prefixes for order.
- Secrets are `age`-encrypted in the source. The age identity is itself decrypted on first apply with a passphrase.
- Lifecycle:
  - **New machine:** `install.ps1` installs winget, chezmoi, DSC, and PowerShell 7, then runs
    `chezmoi init --apply Ermesx`.
  - **Update:** `chezmoi update` (git pull + apply). Changed files are rewritten, and `run_onchange_` scripts rerun
    only if their rendered input changed (for example, the DSC run after a `packages.yaml` change).
  - **Preview:** `chezmoi diff` shows what an apply would change.

### Out of scope

chezmoi updates **declared state**, not **package versions**. Upgrading installed apps and modules to newer
versions is handled in the PowerShell profile (`check-updates.ps1.tmpl`: `Check-Updates`, `Update-Apps`,
`Update-Modules`) through winget and PSGallery. It is limited to the packages listed in `packages.yaml`.

## Alternatives considered

| Option | Why rejected |
|---|---|
| Keep `src/` + own build scripts | Custom code for what chezmoi provides (templating, OS filtering, diff, ordering, encryption); OS choice by file name only |
| Symlink managers (GNU Stow, dotbot) | No templating or secrets; symlinks on Windows need Developer Mode or admin, and some apps replace symlinks with files |
| yadm / bare git repo | Files live directly in `$HOME`; templating and Windows support are weaker; no script ordering model |
| Nix Home Manager | No native Windows support; high learning and maintenance cost for one user |
| Ansible | Needs Python and a control node, with no native Windows control node; too heavy for a workstation and still needs a separate dotfiles layout |

## Consequences

Positive:

- One source, one command to set up or update a machine; `chezmoi diff` before apply.
- Per-OS differences live inside files, so shared config (git, starship) is not duplicated.
- Secrets stay in the repo, encrypted, with no separate secret store.
- The build scripts and `Dotfiles-Toolkit` installer code are gone; the remaining custom code is limited to
  scripts that do work chezmoi does not do (DSC run, font, WSL, yazi plugins).
- A single binary from winget with no runtime dependencies, so it fits the bootstrap in `install.ps1`.

Negative / costs:

- **Learning cost and silent conventions.** Behavior is driven by file-name attributes (`dot_`, `readonly_`,
  `run_onchange_before_`). A wrong separator silently changes semantics; three scripts already use a dash instead of
  an underscore and lost their phase (`docs/known-issues.md`).
- **Scripts are not previewable.** `chezmoi diff` excludes scripts (`[diff] exclude = ["scripts"]`), and a
  `run_onchange_` script with side effects (DSC, `HKLM`, services) runs on the next apply. Testing needs the VM.
- **Update is partial by design.** `chezmoi update` does not upgrade software versions. Manual drift on the machine
  is corrected for files, but not for state set by scripts that do not rerun.

## When to revisit

- chezmoi stops being maintained, or a breaking change in its attribute or template model.
