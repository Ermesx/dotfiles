Dotfiles for Windows & Linux
===========================================================

This repository contains dotfiles and automation scripts to deliver a repeatable, cross-platform setup on Windows and
Linux using chezmoi (templated dotfiles) and WinGet DSC (declarative app/module state on Windows). All configuration is
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

## 📦 Installed Applications & Modules

<!-- BEGIN:packages -->
| Name                                                       | Category   | Install Type | Purpose                              |
|------------------------------------------------------------|------------|--------------|--------------------------------------|
| PowerShell 7 (Microsoft.PowerShell)                        | shell      | App          | Modern PowerShell shell              |
| Starship (Starship.Starship)                               | shell      | App          | Cross-shell prompt                   |
| Windows Terminal (Microsoft.WindowsTerminal)               | shell      | App          | Terminal emulator                    |
| jq (jqlang.jq)                                             | shell      | App          | JSON processor                       |
| zoxide (ajeetdsouza.zoxide)                                | shell      | App          | Smart directory navigation           |
| yazi (sxyazi.yazi)                                         | shell      | App          | TUI file manager                     |
| AIChat (sigoden.AIChat)                                    | shell      | App          | LLM chat CLI                         |
| Microsoft.WinGet.Client                                    | shell      | Module       | Winget cmdlets for DSC               |
| Terminal-Icons                                             | shell      | Module       | File and folder icons in terminal    |
| yazi-rs/plugins:full-border                                | shell      | Yazi plugin  | Full border for yazi panes           |
| fzf (junegunn.fzf)                                         | fzf        | App          | Fuzzy finder                         |
| fd (sharkdp.fd)                                            | fzf        | App          | Fast file search                     |
| ripgrep (BurntSushi.ripgrep.MSVC)                          | fzf        | App          | Fast text search                     |
| eza (eza-community.eza)                                    | fzf        | App          | Modern ls replacement                |
| bat (sharkdp.bat)                                          | fzf        | App          | Syntax-highlighting cat              |
| PSfzf                                                      | fzf        | Module       | PowerShell integration for fzf       |
| Git (Git.Git)                                              | git        | App          | Git version control                  |
| onefetch (o2sh.onefetch)                                   | git        | App          | Repo summary in terminal             |
| delta (dandavison.delta)                                   | git        | App          | Syntax-highlighted diffs             |
| less (jftuga.less)                                         | git        | App          | Pager utility                        |
| lazygit (JesseDuffield.lazygit)                            | git        | App          | TUI for Git                          |
| gitql (amrdeveloper.gitql)                                 | git        | App          | Query Git repos with SQL-like syntax |
| GitHub CLI (GitHub.cli)                                    | git        | App          | GitHub from the terminal             |
| posh-git                                                   | git        | Module       | Git prompt enhancements              |
| Microsoft .NET SDK 10 (Microsoft.DotNet.SDK.10)            | dotnet     | App          | .NET 10 SDK                          |
| dotnet-ef (dotnet-ef)                                      | dotnet     | Tool         | EF Core migrations CLI               |
| dotnet-reportgenerator (dotnet-reportgenerator-globaltool) | dotnet     | Tool         | Coverage report generator            |
| dotnet-outdated (dotnet-outdated-tool)                     | dotnet     | Tool         | Check outdated NuGet packages        |
| dotnet-user-secrets (dotnet-user-secrets)                  | dotnet     | Tool         | Manage user secrets                  |
| dotnet-dev-certs (dotnet-dev-certs)                        | dotnet     | Tool         | Manage dev HTTPS certs               |
| gitversion (gitversion.tool)                               | dotnet     | Tool         | Semantic version from git            |
| dotnet-coverage (dotnet-coverage)                          | dotnet     | Tool         | Collect code coverage                |
| dotnet-trace (dotnet-trace)                                | dotnet     | Tool         | Performance tracing                  |
| dotnet-counters (dotnet-counters)                          | dotnet     | Tool         | Monitor performance counters         |
| dotnet-dump (dotnet-dump)                                  | dotnet     | Tool         | Dump process analysis                |
| dotnet-stack (dotnet-stack)                                | dotnet     | Tool         | Managed stack trace tool             |
| refitter                                                   | dotnet     | Tool         | Refit client generator from OpenAPI  |
| Node.js (OpenJS.NodeJS)                                    | node       | App          | JavaScript runtime                   |
| Docker Desktop (Docker.DockerDesktop)                      | containers | App          | Docker engine & UI                   |
| Vagrant (Hashicorp.Vagrant)                                | containers | App          | VM environments for testing          |
| DockerCompletion                                           | containers | Module       | Docker command completion            |
| chezmoi (twpayne.chezmoi)                                  | chezmoi    | App          | Templated dotfiles manager           |
| Visual Studio Code (Microsoft.VisualStudioCode)            | editors    | App          | Code editor                          |
| JetBrains Rider (JetBrains.Rider)                          | editors    | App          | .NET IDE                             |
| Google Chrome (Google.Chrome)                              | browsers   | App          | Web browser                          |
| PowerToys (Microsoft.PowerToys)                            | other      | App          | Power utilities for Windows          |
| Scalar (APIDocumentation.Scalar)                           | other      | App          | API client and docs                  |
| powershell-yaml                                            | other      | Module       | YAML parsing for PowerShell          |
| Pester                                                     | other      | Module       | PowerShell testing framework         |
| Ubuntu-24.04                                               | other      | WSL distro   | Linux distro for WSL                 |
<!-- END:packages -->

---

See key bindings and shortcuts here: [docs/bindings.md](docs/bindings.md)
