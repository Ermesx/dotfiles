# 🔑 Custom PSReadLine Keybindings Cheat Sheet

<!-- BEGIN:bindings -->
## ✏️ Navigation & Editing

| Shortcut        | Action                                                                         | Source  |
|-----------------|--------------------------------------------------------------------------------|---------|
| Ctrl+RightArrow | Move to the end of the current word                                            | changed |
| Ctrl+Enter      | Validate the input and run it                                                  | changed |
| Ctrl+Spacebar   | Complete input or show menu                                                    | default |
| Ctrl+Alt+c      | Upper case first character, downcase remaining characters of next word         | added   |
| Alt+u           | Make next word upper case                                                      | added   |
| Alt+l           | Make next word lower case                                                      | added   |
| " '             | Insert a pair of quotes, or skip over the closing one                          | added   |
| ( { [           | Insert a matching pair of brackets, or wrap the selection                      | added   |
| ) ] }           | Insert the closing bracket, or skip over an existing one                       | added   |
| Backspace       | Delete the previous character, or an empty pair of quotes or brackets          | changed |
| Alt+'           | Cycle the token under the cursor through single quotes, double quotes and none | added   |
| Ctrl+t          | Pick a path from the current provider with fzf and insert it                   | added   |
| Alt+c           | Pick a directory with fzf and jump to it with zoxide                           | added   |
| Tab             | Run fzf Tab completion                                                         | changed |
| Ctrl+]          | Go to matching brace                                                           | default |
| Ctrl+h          | Delete the character before the cursor                                         | default |
| Alt+.           | Copy the text of the last argument to the input                                | default |
| Alt+a           | Make visual selection of the command arguments                                 | default |
| Ctrl+z          | Undo the last edit                                                             | default |
| Ctrl+y          | Redo the last undone edit                                                      | default |

## 🔍 History & Search

| Shortcut  | Action                                                           | Source  |
|-----------|------------------------------------------------------------------|---------|
| UpArrow   | Search history backward for entries starting with the typed text | changed |
| DownArrow | Search history forward for entries starting with the typed text  | changed |
| Ctrl+r    | Search command history with fzf                                  | changed |
| Ctrl+s    | Search file contents with ripgrep in fzf                         | changed |

## 🌿 Git (PSFzf)

Press the two chords one after another (for example `Ctrl+g`, then `Ctrl+b`).

| Shortcut         | Action                                         | Source |
|------------------|------------------------------------------------|--------|
| Ctrl+g, Ctrl+b   | Pick a Git branch with fzf and insert it       | added  |
| Ctrl+g, Ctrl+f   | Pick a Git file with fzf and insert it         | added  |
| Ctrl+g, Ctrl+h   | Pick a Git commit hash with fzf and insert it  | added  |
| Ctrl+g, Ctrl+p   | Pick a GitHub pull request with fzf            | added  |
| Ctrl+g, Ctrl+s   | Pick a Git stash with fzf and insert it        | added  |
| Ctrl+g, Ctrl+t   | Pick a Git tag with fzf and insert it          | added  |

## 🖥️ Screen Management

| Shortcut | Action                                      | Source  |
|----------|---------------------------------------------|---------|
| Ctrl+p   | Select multiple lines and copy to clipboard | added   |
| Ctrl+l   | Clear the screen and redraw current line    | default |
<!-- END:bindings -->

---
