# ADR-0005: Composable install profiles, chosen at init

- **Status:** Accepted
- **Date:** 2026-11-25
- **Decider:** repository owner
- **Related:** [ADR-0003](0003-windows-packages-via-scoop.md) (amends "each consumer reads the list directly"),
  issue [#20](https://github.com/Ermesx/dotfiles/issues/20), spec [`install-profiles.md`](../specs/install-profiles.md)

## Context

Not every machine should get everything: the work laptop gets no heavy GUI apps it does not need, Rider comes from the
company account there, and Claude Code is replaced by another assistant. Today one `chezmoi apply` installs every
profile in `packages.yaml`, and the PowerShell profile imports every module and runs every completer, so installing
only part of the tools breaks the profile. ADR-0003 left "how profiles are selected" as a separate decision.

## Decision

**Each machine installs the union of the profiles chosen for it, plus individually chosen items in `pick` profiles.
The choice is made at `chezmoi init`, stored in the chezmoi config, and changed only on demand with
`chezmoi init --prompt`. Every consumer reads one filtered view of `packages.yaml` instead of the raw tree.**

- `base` is always installed. `shell`, `sdk` and `containers` are all-or-nothing. `apps` and `ai` (`pick: true`) offer
  each item separately.
- A plain `chezmoi apply` never asks. Re-running `chezmoi init --prompt` asks again with the stored answers as
  defaults, so adding a profile is one tick.
- One shared template (`home/.chezmoitemplates/packages.tmpl`) merges `global` with the current platform and keeps only
  what is selected. The install scripts, the PowerShell profile, Check-Updates and the tests read it. A change that
  alters the view reruns the install scripts (`run_onchange_` hashes the rendered script); a change to an unselected
  profile reruns nothing.
- A config or profile fragment that needs a tool from another profile is conditioned on **that tool** being in the
  view, never on a profile name, so moving a tool between profiles stays a one-line change in `packages.yaml`.
- Deselecting a profile or an item uninstalls nothing.
- An item added later to a `pick` profile is not installed silently: init remembers what it offered, and every apply
  lists new items until `chezmoi init --prompt` decides them.
- CI and the VM choose non-interactively through environment variables the config template reads
  (`DOTFILES_PROFILES`, `DOTFILES_PICKS_<PROFILE>`), chezmoi's documented pattern for containers and VMs;
  `ci.skip_scoop_profiles` goes away, so there is one selection mechanism.

## Options considered

| Option | What I maintain | Why not |
|---|---|---|
| **Selection in chezmoi data + one filtered view** | one view template, prompts in `.chezmoi.toml.tmpl` | — |
| Consumers keep reading the raw tree, each filters by itself | the selection rule in ~9 templates and tests | The rule (profiles, picks, platform merge) repeats everywhere; ADR-0003's "read directly" held only while nothing was filtered |
| One install script per profile (`run_onchange_…-shell`, `…-sdk`) | a script per profile and method | Installs only the new profile naturally, but the profile, Check-Updates, tests and lazygit still need the rule, and per-item picks do not fit a per-profile file |
| Selection in a hand-edited data file | a local YAML per machine | No prompt at init, no non-interactive CI path, typos fail silently |

## Consequences

- A fresh machine is asked once; everything is preselected, so accepting the defaults installs what one apply
  installs today.
- `vscode`, `delta`, `less` and `jq` move to `base`: the git and chezmoi configs in `base` call them.
- The Claude configuration (`~/.claude`, lazygit's AI commit command) is deployed only when `claude-code` is selected.
- The admin step asks for the WSL platform only where a WSL distro or Rancher Desktop is selected, so a machine
  without them and without admin rights is not reminded forever.
- Configuration files of unselected tools (yazi, lazygit, fzf, starship) are still deployed; they are inert without
  the tool.
- An item removed from the selection stays installed until removed by hand (`scoop uninstall`).
