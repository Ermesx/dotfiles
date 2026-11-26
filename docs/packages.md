# Packages

- `home/.chezmoidata/packages.yaml` is the source of truth for what gets installed: Scoop apps, PowerShell modules,
  dotnet tools, yazi plugins, WSL distro, Linux packages. Templates, install scripts, profile `Import-Module`
  lines, and tests all derive from it — never add a package anywhere else.
- Schema: `packages.<platform>.profiles.<profile>.<method>: [items]`. Platform is `global` (added to every
  platform), `windows` or `linux`. Profiles are listed in the glossary below; a profile may be missing on a
  platform. `pick: true` marks a profile whose items are offered one by one at init (see *Profiles and selection*).
- Consumers do not read the tree: they read the view, `home/.chezmoitemplates/packages.tmpl`, which filters it by
  the stored selection (see *Profiles and selection*). The WSL distro has two consumers:
  `run_once_before_install-wsl.ps1.tmpl` and the profile function `Complete-UserSetup`
  (`home/dot_profile/user-setup_profile.ps1.tmpl`).
- Everything installed on Windows lands in user scope and needs no admin rights. What does need admin (Developer
  Mode, the WSL platform, the `ssh-agent` service) is in admin scripts that chezmoi deploys to
  `~/.config/dotfiles/admin/` and never runs; `admin-setup.ps1` runs all three, and every apply ends with a reminder
  (`run_after_zz-admin-reminder.ps1.tmpl`) while any of them is missing; the reminder and `admin-setup.ps1.tmpl`
  mention WSL only when a WSL distro or `rancher-desktop` is selected. They change only the machine and point the user
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

## Profiles and selection

`chezmoi init` asks which profiles to install (`base` is always on), then for every selected profile with
`pick: true` which of its items. `home/.chezmoi.toml.tmpl` stores the answers in the chezmoi config:

| Key | Holds |
|---|---|
| `profiles` | Selected profiles |
| `picks.<profile>` | Selected items of a `pick` profile; an item is identified by its label: the name after the last `/` |
| `offered.<profile>` | Labels already decided on, for every `pick` profile on the platform, selected or not; an item not in it is new |

- Plain `chezmoi apply` never asks. Change the selection with `chezmoi init --prompt`: the defaults are the stored
  answers, and items not yet in `offered` are preselected. An apply that finds such items ends with a notice from
  `run_after_zz-new-picks.ps1.tmpl`.
- `offered.<profile>` becomes every current label when the items were actually decided: on an init with `--prompt`,
  on the first init, in environment mode, and for a profile that is not selected. An init without `--prompt` (for
  example `install.ps1` run again) asks nothing, so a selected profile keeps its stored `offered` and the notice
  stays until `chezmoi init --prompt`.
- A stored profile or item that `packages.yaml` no longer declares is dropped at the next init.
- Non-interactive (CI, scripts): `DOTFILES_PROFILES` (comma-separated; `base` alone means only base) and
  `DOTFILES_PICKS_<PROFILE>` (comma-separated labels). Env mode never prompts; a missing picks variable selects all
  items of that profile; an unknown profile or item name fails init.
- Without a stored selection (a template rendered before any init) every profile and every item counts as selected.
- Deselecting uninstalls nothing, and files already deployed for a deselected tool stay in `$HOME`: chezmoi
  leaves targets it now ignores. The profile only stops loading them.

### The view

Every consumer (install scripts, profile template, tests, the admin step) reads
`includeTemplate "packages.tmpl" . | fromJson`; none ranges over `.packages` itself. Keys:

| Key | Holds |
|---|---|
| `profiles` | Selected profile names, `base` included |
| `scoop`, `modules`, `dotnet_tools`, `yazi_plugins` | Items of the selected profiles and picks, global and the current OS merged |
| `wsl` | The WSL distro, or an empty string |
| `wsl_platform` | `true` when the Windows WSL platform (the admin step) is needed: a distro is set or `rancher-desktop` is selected. The Ubuntu distro itself still comes only with `sdk` |
| `tools` | Labels of every selected item: Scoop app name (no bucket), module, dotnet tool and yazi plugin |
| `pending` | Per `pick` profile, the items not yet in `offered` |

### Config follows the tool, not the profile

Config that needs a tool from another profile is conditioned on the tool name in `tools` (for example
`has "claude-code" $v.tools`), never on a profile name: the profile that holds a tool can change, the tool name
cannot. `base` config must not rely on tools outside `base`; that is why `vscode`, `delta`, `less` and `jq` are in
`base`.

### Add a profile or an item

- A profile: add `<name>:` under its platform in `packages.yaml`, a row to the glossary above, and its name to the
  profile order in `.claude/agents/docs-sync.md`. The init prompt lists it by itself, but an existing machine gets
  it only through `chezmoi init --prompt`, and nothing announces it (the new-picks notice covers items, not
  profiles).
- An item: add it to the method list. In a `pick` profile it is offered at the next `chezmoi init --prompt` and
  announced by the new-picks notice on apply.
- Tool-specific profile code: `home/dot_profile/tools/[zz-]<tool>.ps1`, where `<tool>` is exactly the label in
  `tools`, plus nothing else: the profile template finds it in the folder and loads fragments in file-name order, so
  a `zz-` prefix makes one load after the others. `.chezmoiignore` deploys the file only when the tool is selected.
