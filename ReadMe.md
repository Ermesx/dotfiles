Dotfiles for Windows & Linux
===========================================================

This repository contains dotfiles and automation scripts to deliver a repeatable, cross-platform setup on Windows and
Linux using chezmoi (templated dotfiles) and WinGet DSC (declarative app/module state on Windows). All configuration is
template-driven so the same source adapts per OS and host.


General Architecture
---------------------------------------------------------------

![arch.png](docs/arch.png)

## 🛠️ fzf configuration

1. search
    - files (fd)
    - directories (fd)
    - commands and parameters (get-help)
    - string in files (rg)
2. exclude folders for files and directories (fd and rg)
    - .git,
    - node_modules, etc.
3. can switch between files and directories and commands on the fly
4. do preview of selected item
    - file (bat)
    - directory (esa tree)
    - commands and parameters (get-help)
    - string in file (rg)
5. search shortcut for all types `Ctrl+t`

fd --type file --color=always --exclude .git

fd --type directory {}

---

## 📦 Installed Applications & Modules

| Application                 | Category | Install Type | Purpose                                           |
|-----------------------------|----------|--------------|---------------------------------------------------|
| **PowerShell 7**            | Shell    | App          | Modern PowerShell shell                           |
| **Microsoft.WinGet.Client** | Shell    | Module       | Package management through winget                 |
| **Pester**                  | Shell    | Module       | Testing framework for PowerShell                  |
| **fzf**                     | Shell    | App          | Fuzzy finder for files, directories, and commands |
| **PSfzf**                   | Shell    | Module       | Fuzzy finder integration for PowerShell           |
| **fd**                      | Shell    | App          | Fast file search tool                             |
| **ripgrep (rg)**            | Shell    | App          | Fast text search in files                         |
| **bat**                     | Shell    | App          | Syntax highlighting cat replacement               |
| **zoxide**                  | Shell    | App          | Smart directory navigation                        |
| **eza**                     | Shell    | App          | Modern ls replacement with colors                 |
| **file**                    | Shell    | App          | File type identification utility                  |
| **Oh My Posh**              | Shell    | App          | Prompt theme engine                               |
| **Terminal-Icons**          | Shell    | Module       | File and folder icons in terminal                 |
| **DockerCompletion**        | Shell    | Module       | Docker command completion                         |
| **Git**                     | Shell    | App          | Git version control system                        |
| **posh-git**                | Shell    | Module       | Git integration for PowerShell prompt             |
| **Git Credential Manager**  | Shell    | App          | Git credential helper                             |
| **lazygit**                 | Shell    | App          | Console Git UI                                    |
| **gitql**                   | Shell    | App          | Git query language like SQL                       |
| **onefetch**                | Shell    | App          | Git repository statistics                         |

---

See key bindings and shortcuts here: [docs/bindings.md](docs/bindings.md)
