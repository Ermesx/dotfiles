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


Installed CLI tools
-------------------
1. git

Installed Apps
--------------
1. Rider
2. VS Code


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