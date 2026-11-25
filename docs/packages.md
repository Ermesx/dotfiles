# Packages

- `home/.chezmoidata/packages.yaml` is the source of truth for what gets installed: Scoop apps, PowerShell modules,
  dotnet tools, yazi plugins, WSL distro, Linux packages. Templates, install scripts, profile `Import-Module`
  lines, and tests all derive from it — never add a package anywhere else.
- Schema: `packages.<platform>.profiles.<profile>.<method>: [items]`. Platform is `global` (added to every
  platform), `windows` or `linux`. Profiles are listed in the glossary below; a profile may be missing on a
  platform. `pick: true` marks a profile whose items are offered one by one at init; it is ignored until #20.
- Consumers read the tree directly: they range over `.packages.<platform>.profiles` and read a method with
  `get . "<method>" | default list`, because not every profile has every method. Items that live in one place
  are read by path (`.packages.windows.profiles.sdk.wsl`, `.packages.global.profiles.shell.yazi_plugins`). The
  WSL distro has two consumers: `run_once_before_install-wsl.ps1.tmpl` and the profile function
  `Complete-UserSetup` (`home/dot_profile/user-setup_profile.ps1.tmpl`).
- Everything installed on Windows lands in user scope and needs no admin rights. What does need admin (Developer
  Mode, the WSL platform, the `ssh-agent` service) is in admin scripts that chezmoi deploys to
  `~/.config/dotfiles/admin/` and never runs; `admin-setup.ps1` runs all three, and every apply ends with a reminder
  (`run_after_zz-admin-reminder.ps1`) while any of them is missing. They change only the machine and point the user
  at `Complete-UserSetup` (installs the WSL distro, loads the SSH key), which the user runs without admin.
- A change to `packages.yaml` reruns the install scripts on the next apply (see `docs/chezmoi.md`). Check what a
  script will run by rendering it (command in `AGENTS.md`).
- Updating installed software is Scoop's job, not the YAML's: no version pins.

## Methods

| Platform | Method | Item | Verify with |
|---|---|---|---|
| windows | `scoop` | `[bucket/]app`; a bare name is the `main` bucket | `scoop info <entry>` on a machine with Scoop |
| windows | `modules` | PowerShell Gallery module, installed `-Scope CurrentUser` | `Find-Module <name>` |
| windows | `wsl` | one WSL distro name (a scalar, not a list) | `wsl --list --online` |
| global | `dotnet_tools` | .NET global tool package id | `dotnet tool search <id>` |
| global | `yazi_plugins` | `owner/repo:plugin`, installed with `ya pkg add` | the plugin repository |
| linux | `brew` | Homebrew formula | `brew info <name>` |
| linux | `zsh_plugins` | zsh plugin name | the plugin repository |

- The bucket is taken from the `bucket/` prefix. An entry with a new bucket adds that bucket to the machine: a trust
  decision, because a bucket is third-party code that runs on install. Prefer `main`, `extras` and `nerd-fonts`;
  add another bucket only on purpose.
- Every module under `modules` is imported in every PowerShell session. Add only modules that are cheap to
  import.
- Linux content is data only; no Linux script reads it yet (#12).

## Profiles

A profile groups items by purpose. Its name is the *Profile* value of the package table in `ReadMe.md`, which is
generated from the YAML by the `docs-sync` agent (`.claude/agents/docs-sync.md`): ids and profiles come from the
YAML, names and purposes are kept from the existing rows. Do not edit the table by hand; see
`docs/conventions.md`. Comments inside the YAML are free-form notes and carry no meaning for tooling.

| Profile | What belongs there |
|---|---|
| `base` | What every machine needs: PowerShell, git, chezmoi, archiver, terminal, font, basic utilities |
| `shell` | Shell experience: prompt, navigation, fuzzy finding and search tools, git helpers, shell modules, file manager |
| `sdk` | Development runtimes and tooling: .NET, Node.js, Python, WSL distro, .NET global tools |
| `containers` | Container engine and tools: Rancher Desktop (also the only docker CLI, see ADR-0004), lazydocker |
| `apps` | Optional GUI applications: editors and IDEs, browsers, API clients, VM tooling |
| `ai` | AI coding assistants and their CLIs |
