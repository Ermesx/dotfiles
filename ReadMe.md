Dotfiles for Windows & Linux
===========================================================


Basic installation like, terminal, shell, package manager, etc.
---------------------------------------------------------------


### Windows
1. Update winget
2. Install PowerShell 7 
3. Windows terminal


### Linux
1. Install brew
2. Install zsh


## Requirements
1. Install/Update is a simple list of applications and modules
   1. as foreach loop
   2. should be visible installed version
2. Setup is optional and do one-time action after installation
3. Configuration is done by static symlinks to the configuration files
   1. easy to update by git pull and git push if needed
   2. part of config is path to destination folder
   3. env variables are a part of the config


# 🔑 Custom PSReadLine Keybindings Cheat Sheet

## ✏️ Navigation & Editing
| Shortcut      | Purpose                                                                |
|---------------|------------------------------------------------------------------------|
| Ctrl+]        | Go to matching brace                                                   |
| Ctrl+Spacebar | Complete input or show menu                                            |
| Tab           | Run fzf Tab completion                                                 |
| Alt+c         | Upper case first character, downcase remaining characters of next word |
| Alt+l         | Make next word lower case                                              |
| Alt+u         | Make next word upper case                                              |
| Ctrl+h        | Delete the character before the cursor                                 |
| Alt+.         | Copy the text of the last argument to the input                        |
| Alt+a         | Make visual selection of the command arguments                         |

## 🔍 History & Search
| Shortcut | Purpose                                             |
|----------|-----------------------------------------------------|
| Ctrl+r   | Run fzf Search in files by ripgrep                  |
| Ctrl+f   | Run fzf for current provider based on current token |
| Ctrl+h   | Run fzf to search through PSReadline history        |
| Ctrl+d   | Run Fzf directory search                            |

## 🖥️ Screen Management
| Shortcut   | Purpose                                         |
|------------|-------------------------------------------------|
| Ctrl+p     | Select multiple lines and copy to clipboard     |
| Ctrl+l     | Clear the screen and redraw current line        |

---

# 🛠️ fzf configuration

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

# 📦 Installed Applications & Modules

## 🛠️ Applications & CLI Tools
| Application                 | Category | Install Type | Purpose                                           |
|-----------------------------|----------|--------------|---------------------------------------------------|
| **PowerShell 7**            | Shell    | App          | Modern PowerShell shell                           |
| **Microsoft.WinGet.Client** | Shell    | Module       | Package management through winget                 |
| **Pester**                  | Shell    | Module       | Testing framework for PowerShell                  |
| **PSScriptAnalyzer**        | Shell    | Module       | Static code analysis for PowerShell               |
| **PSMustache**              | Shell    | Module       | Template engine for PowerShell                    |
| **Dotfiles-Toolkit**        | Shell    | Module       | Custom toolkit for dotfiles management            |
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
| **Windows Terminal**        | Desktop  | App          | Modern terminal application                       |

