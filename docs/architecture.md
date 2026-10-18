# Architecture

What the repo can do and where each capability starts. These are hints, not a directory map: build the map you
need with `chezmoi --source . managed` while planning and keep it in your plan, not in these docs.

## Shape

- One chezmoi source in `home/` (`.chezmoiroot`) renders per OS and host. Everything outside `home/` is repo
  tooling and is never applied to `$HOME`.
- On Windows, software state is declarative: `home/.chezmoidata/packages.yaml` is rendered into a DSC v3 document
  that drives `Microsoft.WinGet/Package`, `PowerShellModule/PSModuleResource`, and
  `Microsoft.DotNet.Dsc/DotNetToolPackage` resources. Rationale and exceptions:
  [ADR-0001](adr/0001-windows-packages-via-dsc-v3.md).
- Bootstrap is `install.ps1` (published at `https://getdotfiles.short.gy/install.ps1`): it ensures winget, installs
  chezmoi, Microsoft DSC, and PowerShell 7, then runs `chezmoi init --apply Ermesx`.

## Capabilities

| Capability | Start from |
|---|---|
| Declarative install of apps, PowerShell modules, .NET tools, yazi plugins, WSL distro | `home/.chezmoidata/packages.yaml`, then its consumers (grep for `.packages`) |
| Applying that state on Windows | The DSC template in `home/.chezmoitemplates/` and the numbered scripts in `home/.chezmoiscripts/windows/` |
| One-off machine setup (font, WSL, ssh-agent key, key decryption) | `home/.chezmoiscripts/<os>/`; font choice in `home/.chezmoidata/` |
| PowerShell shell experience (modules, PSReadLine, fzf, completers, prompt, update checks) | The profile template under `home/readonly_Documents/PowerShell/` and the fragments it dot-sources |
| Per-app configuration (terminal, git, starship, lazygit, bat, yazi, …) | `home/dot_*` for `$HOME`, `home/readonly_AppData/` for `%APPDATA%` / `%LOCALAPPDATA%` |
| Secrets and identity | `*.age` / `encrypted_*` files and `home/.chezmoi.toml.tmpl` |
| OS-specific behavior | `.chezmoiignore` files and `.chezmoi.os` branches inside templates |
| Testing a full install | `tests/` (Vagrant + Pester) |
| Claude Code configuration (`~/.claude`, allowlisted files only) | `home/dot_claude/` and the `.claude` entries in `home/.chezmoiignore`; general rules in [chezmoi.md](chezmoi.md#config-that-the-app-rewrites) |
| README package table and key bindings list kept in sync with their sources | `.claude/agents/docs-sync.md` (agent) and `.claude/hooks/docs-sync-trigger.py` (reminder hook, wired in `.claude/settings.json`) |

