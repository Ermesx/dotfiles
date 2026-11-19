# Packages

- `home/.chezmoidata/packages.yaml` is the source of truth for what gets installed: Scoop apps, PowerShell modules,
  dotnet tools, yazi plugins, WSL distro, Linux packages. Templates, install scripts, profile `Import-Module`
  lines, and tests all derive from it — never add a package anywhere else.
- Schema: `packages.<platform>.profiles.<profile>.<method>: [items]`. Platform is `global` (added to every
  platform), `windows` or `linux`. Profiles are listed in the glossary below; a profile may be missing on a
  platform. `pick: true` marks a profile whose items are offered one by one at init; it is ignored until #20.
- Consumers never read the raw tree. `home/.chezmoitemplates/packages.tmpl` merges `global` with the current
  platform into one list per method; read it with `includeTemplate "packages.tmpl" . | fromJson` (command in
  `AGENTS.md`).
- Everything installed on Windows lands in user scope and needs no admin rights. What does need admin (Developer
  Mode, the WSL platform, the `ssh-agent` service) lives in `scripts/admin/`; chezmoi never runs those scripts
  (the aggregate script and the reminder are #44).
- A change to `packages.yaml` reruns the install scripts on the next apply (see `docs/chezmoi.md`). Check what the
  scripts will read with the package view command in `AGENTS.md`.
- Updating installed software is Scoop's job, not the YAML's: no version pins.

## Methods

| Platform | Method | Item | Verify with |
|---|---|---|---|
| windows | `scoop` | `[bucket/]app`; a bare name is the `main` bucket | `scoop info <entry>` on a machine with Scoop |
| windows | `modules` | PowerShell Gallery module, installed `-Scope CurrentUser` | `Find-Module <name>` |
| windows | `wsl` | WSL distro name | `wsl --list --online` |
| global | `dotnet_tools` | .NET global tool package id | `dotnet tool search <id>` |
| global | `yazi_plugins` | `owner/repo:plugin`, installed with `ya pkg add` | the plugin repository |
| linux | `brew` | Homebrew formula | `brew info <name>` |
| linux | `zsh_plugins` | zsh plugin name | the plugin repository |

- The bucket is taken from the `bucket/` prefix. An entry with a new bucket adds that bucket to the machine: a trust
  decision, because a bucket is third-party code that runs on install. Prefer `main`, `extras` and `nerd-fonts`;
  add another bucket only on purpose.
- Every module in the view's `modules` is imported in every PowerShell session. Add only modules that are cheap to
  import.
- Linux content is data only; no Linux script reads it yet (#12).

## Profiles

A profile groups items by purpose. Its name is the *Category* value of the package table in `ReadMe.md`, which is
generated from the YAML by the `docs-sync` agent (`.claude/agents/docs-sync.md`): ids and categories come from the
YAML, names and purposes are kept from the existing rows. Do not edit the table by hand; see
`docs/conventions.md`. Comments inside the YAML are free-form notes and carry no meaning for tooling.

| Profile | What belongs there |
|---|---|
| `base` | What every machine needs: PowerShell, git, chezmoi, archiver, terminal, font, basic utilities |
| `shell` | Shell experience: prompt, navigation, fuzzy finding and search tools, git helpers, shell modules, file manager |
| `sdk` | Development runtimes and tooling: .NET, Node.js, Python, container clients, WSL distro, .NET global tools |
| `apps` | Optional GUI applications: editors and IDEs, browsers, API clients, VM tooling |
| `ai` | AI coding assistants and their CLIs |
