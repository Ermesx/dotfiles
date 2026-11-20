Dotfiles for Windows & Linux
===========================================================

This repository contains dotfiles and automation scripts to deliver a repeatable, cross-platform setup on Windows and
Linux using chezmoi (templated dotfiles) and Scoop (declarative, user-scope app/module state on Windows). All configuration is
template-driven so the same source adapts per OS and host.

Installation
---------------------------------------------------------------

```powershell
# Windows
iex (irm 'https://getdotfiles.short.gy/install.ps1' | Out-String)
```

```zsh
# Linux / macOS
sh -c "$(curl -fsLS https://getdotfiles.short.gy/install.sh)"
```

General Architecture
---------------------------------------------------------------

![arch.png](docs/arch.png)

Daily use
---------------------------------------------------------------

Everything is managed by chezmoi with this repo as the source (`home/`). Change the source, not the files in `$HOME`.
Rationale: [ADR-0002](docs/adr/0002-chezmoi-as-dotfiles-manager.md); source layout and attributes:
[docs/chezmoi.md](docs/chezmoi.md).

| Goal | Command |
|---|---|
| Get changes from the repo | `chezmoi update` (git pull + apply) |
| Preview before applying | `chezmoi status`, `chezmoi diff` |
| Change a config | `chezmoi edit <target>` (opens VS Code), then `chezmoi apply` |
| Pick up a file edited in `$HOME` | `chezmoi re-add` (all tracked) or `chezmoi add <target>` (new file) |
| Add a secret | `chezmoi add --encrypt <target>` |
| Resolve drift or a conflict | `chezmoi merge <target>` |
| Commit and publish | `chezmoi cd`, then `git commit` / `git push` on a branch off `develop` |
| Upgrade apps and modules | `Check-Updates`, `Update-Apps`, `Update-Modules` (PowerShell profile) |

Things that bite:

- `chezmoi diff` excludes scripts (`[diff] exclude = ["scripts"]`), but `chezmoi apply` and `update` still run them.
  `run_onchange_` scripts (the Scoop install script among them) rerun only when their rendered input changed, for example after a
  `packages.yaml` edit, and they install software.
- `chezmoi re-add` does not update `.tmpl` sources: it skips templates. Change those in the source with
  `chezmoi edit`.
- `chezmoi update` aligns the declared state only. It does not upgrade installed apps or modules; use the update
  commands above (limited to the packages in `packages.yaml`).
- `git.autoCommit` / `git.autoPush` are deliberately off: changes go through a branch off `develop` and Conventional
  Commits, which auto-commit on the current branch would bypass.

## 📦 Installed Applications & Modules

<!-- BEGIN:packages -->
| Name                                                       | Profile | Install Type | Purpose                              |
|------------------------------------------------------------|---------|--------------|--------------------------------------|
| PowerShell 7 (pwsh)                                        | base    | App          | Modern PowerShell shell              |
| Git (git)                                                  | base    | App          | Git version control                  |
| chezmoi (chezmoi)                                          | base    | App          | Templated dotfiles manager           |
| 7-Zip (7zip)                                               | base    | App          | File archiver                        |
| Windows Terminal (extras/windows-terminal)                 | base    | App          | Terminal emulator                    |
| PowerToys (extras/powertoys)                               | base    | App          | Power utilities for Windows          |
| Caffeine (extras/caffeine)                                 | base    | App          | Keep the screen awake                |
| Hasklig Nerd Font (nerd-fonts/Hasklig-NF)                  | base    | App          | Programming font with ligatures      |
| Starship (starship)                                        | shell   | App          | Cross-shell prompt                   |
| jq (jq)                                                    | shell   | App          | JSON processor                       |
| zoxide (zoxide)                                            | shell   | App          | Smart directory navigation           |
| yazi (yazi)                                                | shell   | App          | TUI file manager                     |
| fzf (fzf)                                                  | shell   | App          | Fuzzy finder                         |
| fd (fd)                                                    | shell   | App          | Fast file search                     |
| ripgrep (ripgrep)                                          | shell   | App          | Fast text search                     |
| eza (eza)                                                  | shell   | App          | Modern ls replacement                |
| bat (bat)                                                  | shell   | App          | Syntax-highlighting cat              |
| onefetch (extras/onefetch)                                 | shell   | App          | Repo summary in terminal             |
| delta (delta)                                              | shell   | App          | Syntax-highlighted diffs             |
| less (less)                                                | shell   | App          | Pager utility                        |
| lazygit (extras/lazygit)                                   | shell   | App          | TUI for Git                          |
| gitql (gitql)                                              | shell   | App          | Query Git repos with SQL-like syntax |
| GitHub CLI (gh)                                            | shell   | App          | GitHub from the terminal             |
| Gitleaks (gitleaks)                                        | shell   | App          | Secret scanner for Git repos         |
| GnuPG (gpg)                                                | shell   | App          | Encryption and signing tool          |
| Terminal-Icons                                             | shell   | Module       | File and folder icons in terminal    |
| PSfzf                                                      | shell   | Module       | PowerShell integration for fzf       |
| posh-git                                                   | shell   | Module       | Git prompt enhancements              |
| yazi-rs/plugins:full-border                                | shell   | Yazi plugin  | Full border for yazi panes           |
| Microsoft .NET SDK (dotnet-sdk)                            | sdk     | App          | .NET SDK, latest release             |
| Node.js (nodejs)                                           | sdk     | App          | JavaScript runtime                   |
| Python (python)                                            | sdk     | App          | Python runtime                       |
| uv (uv)                                                    | sdk     | App          | Python package manager               |
| Docker CLI (docker)                                        | sdk     | App          | Docker command-line client           |
| Docker Compose (docker-compose)                            | sdk     | App          | Multi-container orchestration        |
| Docker Buildx (docker-buildx)                              | sdk     | App          | Extended image builder               |
| lazydocker (lazydocker)                                    | sdk     | App          | TUI for Docker                       |
| DockerCompletion                                           | sdk     | Module       | Docker command completion            |
| powershell-yaml                                            | sdk     | Module       | YAML parsing for PowerShell          |
| Pester                                                     | sdk     | Module       | PowerShell testing framework         |
| dotnet-ef (dotnet-ef)                                      | sdk     | Tool         | EF Core migrations CLI               |
| dotnet-reportgenerator (dotnet-reportgenerator-globaltool) | sdk     | Tool         | Coverage report generator            |
| dotnet-outdated (dotnet-outdated-tool)                     | sdk     | Tool         | Check outdated NuGet packages        |
| dotnet-user-secrets (dotnet-user-secrets)                  | sdk     | Tool         | Manage user secrets                  |
| dotnet-dev-certs (dotnet-dev-certs)                        | sdk     | Tool         | Manage dev HTTPS certs               |
| gitversion (gitversion.tool)                               | sdk     | Tool         | Semantic version from git            |
| dotnet-coverage (dotnet-coverage)                          | sdk     | Tool         | Collect code coverage                |
| dotnet-trace (dotnet-trace)                                | sdk     | Tool         | Performance tracing                  |
| dotnet-counters (dotnet-counters)                          | sdk     | Tool         | Monitor performance counters         |
| dotnet-dump (dotnet-dump)                                  | sdk     | Tool         | Dump process analysis                |
| dotnet-stack (dotnet-stack)                                | sdk     | Tool         | Managed stack trace tool             |
| refitter                                                   | sdk     | Tool         | Refit client generator from OpenAPI  |
| Ubuntu-24.04                                               | sdk     | WSL distro   | Linux distro for WSL                 |
| Visual Studio Code (extras/vscode)                         | apps    | App          | Code editor                          |
| JetBrains Rider (extras/rider)                             | apps    | App          | .NET IDE                             |
| Google Chrome (extras/googlechrome)                        | apps    | App          | Web browser                          |
| Postman (extras/postman)                                   | apps    | App          | API client                           |
| Vagrant (vagrant)                                          | apps    | App          | VM environments for testing          |
| Claude Code (claude-code)                                  | ai      | App          | AI coding assistant CLI              |
<!-- END:packages -->

---

See key bindings and shortcuts here: [docs/terminal-bindings.md](docs/terminal-bindings.md)
