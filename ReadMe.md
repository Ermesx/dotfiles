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

### ✂️ Text Editing

| Shortcut              | Function          | Description                                                    |
|-----------------------|-------------------|----------------------------------------------------------------|
| `Ctrl+Alt+Backspace`  | BackwardKillInput | Delete everything from the cursor to the beginning of the line |
| `Shift+Alt+Backspace` | KillLine          | Delete everything from the cursor to the end of the line       |
| `Ctrl+Backspace`      | BackwardKillWord  | 🔥 Delete previous word (like in most Windows editors)         |
| `Ctrl+z`              | Undo              | 🔁 Undo last edit                                              |
| `Ctrl+y`              | Redo              | 🔁 Redo the last undone change                                 |
| `Alt+c`               | CapitalizeWord    | Capitalize next word                                           |
| `Alt+u`               | UppercaseWord     | Make next word uppercase                                       |
| `Alt+l`               | DowncaseWord      | Make next word lowercase                                       |

### ⌨️ Cursor Movement and Selection

| Shortcut                | Function           | Description                          |
|-------------------------|--------------------|--------------------------------------|
| `Ctrl+LeftArrow`        | BackwardWord       | 🔄 Move cursor one word to the left  |
| `Ctrl+RightArrow`       | ForwardWord        | 🔄 Move cursor one word to the right |
| `Ctrl+Shift+LeftArrow`  | SelectBackwardWord | 🔲 Select one word to the left       |
| `Ctrl+Shift+RightArrow` | SelectForwardWord  | 🔲 Select one word to the right      | `Ctrl+RightArrow`  | ForwardWord     | 🔄 Move cursor one word to the right                |

### 🧩 Other Nice Shortcuts

| Shortcut        | Function              | Description                                          |
|-----------------|-----------------------|------------------------------------------------------|
| `Alt+.`         | YankLastArg           | Insert the last argument from the previous command   |
| `Alt+'`         | ToggleQuoteArgument   | Toggle quotes around the argument under the cursor   |
| `Ctrl+Enter`    | ValidateAndAcceptLine | ✅ Validate and run input only if syntax is correct   |
| `Ctrl+Spacebar` | MenuComplete          | Show a menu of available completions                 |
| `Ctrl+l`        | ClearScreen           | Clear the terminal and redraw the prompt at the top  |
| `Ctrl+p`        | CaptureScreen         | 📸 Copy selected lines to clipboard (for logs/debug) |

### 🔍 Fuzzy Search with fzf (PSfzf module)

| Shortcut | Function                | Description                        |
|----------|-------------------------|------------------------------------|
| `Ctrl+t` | FzfProviderSelect       | Search files or items via `fzf`    |
| `Ctrl+h` | FzfReverseHistorySelect | Search command history using `fzf` |

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