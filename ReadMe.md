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

| Name                                            | Category | Install Type | Purpose                              |
|-------------------------------------------------|----------|--------------|--------------------------------------|
| PowerShell 7 (Microsoft.PowerShell)             | Shell    | App          | Modern PowerShell shell              |
| Starship (Starship.Starship)                    | Shell    | App          | Cross-shell prompt                   |
| Windows Terminal (Microsoft.WindowsTerminal)    | Shell    | App          | Terminal emulator                    |
| zoxide (ajeetdsouza.zoxide)                     | Shell    | App          | Smart directory navigation           |
| fzf (junegunn.fzf)                              | Shell    | App          | Fuzzy finder                         |
| fd (sharkdp.fd)                                 | Shell    | App          | Fast file search                     |
| ripgrep (BurntSushi.ripgrep.MSVC)               | Shell    | App          | Fast text search                     |
| eza (eza-community.eza)                         | Shell    | App          | Modern ls replacement                |
| bat (sharkdp.bat)                               | Shell    | App          | Syntax-highlighting cat              |
| file (GnuWin32.File)                            | Shell    | App          | File type identification             |
| Git (Git.Git)                                   | Git      | App          | Git version control                  |
| delta (dandavison.delta)                        | Git      | App          | Syntax-highlighted diffs             |
| less (jftuga.less)                              | Shell    | App          | Pager utility                        |
| lazygit (JesseDuffield.lazygit)                 | Git      | App          | TUI for Git                          |
| gitql (amrdeveloper.gitql)                      | Git      | App          | Query Git repos with SQL-like syntax |
| onefetch (o2sh.onefetch)                        | Git      | App          | Repo summary in terminal             |
| Docker Desktop (Docker.DockerDesktop)           | Docker   | App          | Docker engine & UI                   |
| chezmoi (twpayne.chezmoi)                       | Setup    | App          | Templated dotfiles manager           |
| Visual Studio Code (Microsoft.VisualStudioCode) | Editor   | App          | Code editor                          |
| JetBrains Rider (JetBrains.Rider)               | Editor   | App          | .NET IDE                             |
| Google Chrome (Google.Chrome)                   | Browser  | App          | Web browser                          |
| PowerToys (Microsoft.PowerToys)                 | Other    | App          | Power utilities for Windows          |
| yazi (sxyazi.yazi)                              | Shell    | App          | TUI file manager                     |
| Microsoft.WinGet.Client                         | Shell    | Module       | Winget cmdlets for DSC               |
| Terminal-Icons                                  | Shell    | Module       | File and folder icons in terminal    |
| PSfzf                                           | Shell    | Module       | PowerShell integration for fzf       |
| posh-git                                        | Git      | Module       | Git prompt enhancements              |
| DockerCompletion                                | Docker   | Module       | Docker command completion            |
| powershell-yaml                                 | Shell    | Module       | YAML parsing for PowerShell          |
| Pester                                          | Testing  | Module       | PowerShell testing framework         |

---

See key bindings and shortcuts here: [docs/bindings.md](docs/bindings.md)
