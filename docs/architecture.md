# Architecture

What the repo can do and where each capability starts. These are hints, not a directory map: build the map you
need with `chezmoi --source . managed` while planning and keep it in your plan, not in these docs.

## Shape

- One chezmoi source in `home/` (`.chezmoiroot`) renders per OS and host. Everything outside `home/` is repo
  tooling and is never applied to `$HOME`.
- On Windows, software state is declarative and installed in user scope: the numbered install scripts render
  `home/.chezmoidata/packages.yaml` into one command per item: Scoop apps, PowerShell modules (`CurrentUser`),
  .NET global tools. Apply needs no admin rights; machine-level setup is in admin scripts that chezmoi deploys to
  `~/.config/dotfiles/admin/` but never runs. Rationale and exceptions:
  [ADR-0003](adr/0003-windows-packages-via-scoop.md).
- Bootstrap is `install.ps1` (published at `https://getdotfiles.short.gy/install.ps1`), run from a non-elevated
  shell: it sets the `CurrentUser` execution policy, installs Scoop if missing, installs git, chezmoi, and
  PowerShell 7 from Scoop, then runs `chezmoi init --apply Ermesx`.

## Capabilities

| Capability | Start from |
|---|---|
| Declarative install of apps, PowerShell modules, .NET tools, yazi plugins, WSL distro | `home/.chezmoidata/packages.yaml`, then its consumers (grep for `packages.tmpl`) |
| Which profiles and items are installed on this machine | The view `home/.chezmoitemplates/packages.tmpl` over the selection stored by `home/.chezmoi.toml.tmpl`; new items are announced by `run_after_zz-new-picks.ps1.tmpl`; see [packages.md](packages.md) |
| Applying that state on Windows | The numbered scripts `01-scoop`, `02-modules`, `03-dotnet-tools` (then `user-settings` after them) in `home/.chezmoiscripts/windows/` |
| One-off machine setup (WSL distro, ssh-agent key, key decryption) | `home/.chezmoiscripts/<os>/` |
| Setup that needs administrator rights (Developer Mode, WSL platform, ssh-agent service) | `home/dot_config/dotfiles/admin/` (deployed to `~/.config/dotfiles/admin/`, `admin-setup.ps1` runs all); chezmoi never runs it, see [ADR-0003](adr/0003-windows-packages-via-scoop.md). Reminder at the end of apply: `home/.chezmoiscripts/windows/run_after_zz-admin-reminder.ps1.tmpl` (WSL only when a distro or `rancher-desktop` is selected); the user's follow-up: `Complete-UserSetup` in `home/dot_profile/user-setup_profile.ps1.tmpl` |
| PowerShell shell experience (modules, PSReadLine, fzf, completers, prompt, update checks) | The profile template under `home/readonly_Documents/PowerShell/` and the fragments it dot-sources (general ones in `home/dot_profile/`, per-tool ones in `home/dot_profile/tools/`) |
| Per-app configuration (terminal, git, starship, lazygit, bat, yazi, …) | `home/dot_*` for `$HOME`, `home/readonly_AppData/` for `%APPDATA%` / `%LOCALAPPDATA%` |
| Secrets and identity | `*.age` / `encrypted_*` files and `home/.chezmoi.toml.tmpl` |
| OS-specific behavior | `.chezmoiignore` files and `.chezmoi.os` branches inside templates |
| Testing (static checks, CI, full install) | `tests/static/` (static layer), `.github/workflows/ci.yml` (CI on `windows-latest`), `tests/` (Vagrant + Pester); layers in [testing.md](testing.md) |
| Claude Code configuration (`~/.claude`, allowlisted files only; deployed only when `claude-code` is selected) | `home/dot_claude/` and the `.claude` entries in `home/.chezmoiignore`; rationale in [specs/claude-config.md](specs/claude-config.md) |
| README package table and key bindings list kept in sync with their sources | `.claude/agents/docs-sync.md` (agent) and `.claude/hooks/docs-sync-trigger.py` (reminder hook, wired in `.claude/settings.json`) |

