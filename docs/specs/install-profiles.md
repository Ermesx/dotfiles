# Spec: Composable install profiles with per-item picks

Issue: [#20](https://github.com/Ermesx/dotfiles/issues/20) · ADR: [ADR-0005](../adr/0005-composable-install-profiles.md) ·
Status: Draft · Date: 2026-11-25

The issue fixes the direction (profiles that compose, per-item picks in `pick` profiles, selection at `chezmoi init`,
nothing uninstalled). This spec turns it into requirements and corrects what reading the code and chezmoi v2.73.1
showed (marked **[added]**).

## Decisions

| # | Decision | Agreed | Why |
|---|---|---|---|
| D1 | Where the selection rule lives | **Variant A (2026-11-25):** one filtered view template; every consumer reads it | **[added]** The "helper view from #43" was dropped in the PR #50 review (`scoop-user-scope.md` R2) because it only flattened lists. With filtering by profiles and picks it pays for itself: today the CI skip rule alone is repeated in three places |
| D2 | Profiles | `base` (always), `shell`, `sdk`, **`containers`** **[added: from #48]**, `apps`, `ai`. `shell`, `sdk`, `containers` all-or-nothing; `apps`, `ai` per item (`pick: true`) | Issue; `containers` agreed all-or-nothing 2026-11-25 |
| D3 | When the user is asked | Once, at the first `chezmoi init`; again only on demand with `chezmoi init --prompt`; never on `apply` (2026-11-25) | `promptMultichoiceOnce` returns the stored answer unless `--prompt` is given (verified on v2.73.1) |
| D4 | Tools that `base` configs call | **Agreed 2026-11-25:** `extras/vscode`, `delta`, `less`, `jq` move to `base` | **[added]** `.gitconfig` (`pager`, `interactive.diffFilter`, `textconv = jq .`, mergetool `code`) and `.chezmoi.toml.tmpl` (`[diff] pager`, `[edit] command`) are deployed on every machine; without `shell` `git diff`, `git log`, `git add -p` and `chezmoi diff` fail, and VS Code is the editor everywhere |
| D5 | Config that needs a tool from another profile | **Agreed 2026-11-25:** conditioned on the tool being in the view, by its name, never on a profile name | Moving a tool between profiles stays one line in `packages.yaml` |
| D6 | Claude configuration when `claude-code` is not selected | **Agreed 2026-11-25:** not deployed at all (`~/.claude`, `ai-commit.ps1`, lazygit's `<c-a>` command) | It is dead without Claude; the replacement assistant and a shared AI configuration are a separate issue |
| D7 | CI selection | **Agreed 2026-11-25:** `ci.skip_scoop_profiles` is removed; CI and the VM pass the selection with `--promptMultichoice` | One selection mechanism instead of two |
| D8 | Defaults at the first init | **Agreed 2026-11-25:** every profile and every pick preselected | Accepting the defaults installs what one apply installs today; nothing disappears silently |
| D9 | Pester on the VM | **Agreed 2026-11-25:** the VM test runner installs Pester itself, as CI does | `base + shell` has no `sdk`, so no Pester to run the tests with |
| D10 | `ai` with one item | **Agreed 2026-11-25:** stays `pick: true` | A second assistant comes with the follow-up issue |
| O1 | A new item added to a `pick` profile after init | **Open — see below** | **[added]** It is in no stored pick and `promptMultichoiceOnce` does not ask again, so it is silently not installed |

## Requirements

### Selection (`home/.chezmoi.toml.tmpl`)

- **R1** The config template asks, with `promptMultichoiceOnce`, and stores under `[data]`:
  - `profiles`: prompt text `Profiles`; choices: every profile name under `.packages.global.profiles` and
    `.packages.<os>.profiles` except `base`, deduplicated, alphabetical; `base` is never offered and always selected.
  - `picks.<profile>`: one prompt per selected profile with `pick: true` on the current platform, prompt text
    `<profile> items` (e.g. `apps items`); choices: every list item of that profile on the current platform and in
    `global`, as written in the YAML (`extras/rider`, not `rider`). A profile that is not selected stores no picks.
- **R2** **[added]** The default of every prompt is the stored answer when there is one, otherwise everything (D8).
  Verified: with a hard-coded default, `chezmoi init --prompt --promptDefaults` replaced a stored pick of
  `rider/postman` with all items.
- **R3** The answers survive a plain `chezmoi init` (no `--prompt`) and every `chezmoi apply`. Verified on v2.73.1.
- **R4** Non-interactive form, verified on v2.73.1:
  `chezmoi init --promptMultichoice "Profiles=shell/sdk/ai" --promptMultichoice "ai items=claude-code"` — the key is
  the prompt text, values are separated by `/`.
- **R5** `chezmoi init --prompt` asks every prompt again with the stored answers as defaults (R2). Deselecting
  uninstalls nothing (R30).

### View (`home/.chezmoitemplates/packages.tmpl`)

- **R6** Called as `includeTemplate "packages.tmpl" . | fromJson`; renders one JSON object for the current platform
  (`.chezmoi.os`), built from `global` plus that platform.
- **R7** A profile is selected when it is `base` or listed in `.profiles`. **[added]** When `.profiles` is missing
  (no init yet, or `--config` with an empty file as the static tests use), every profile is selected and every pick
  is taken, so templates render as today.
- **R8** An item of a selected `pick` profile is included only when it is listed in `.picks.<profile>`; `pick` itself
  is never an item.
- **R9** Keys:
  - one key per list method present on the platform (`scoop`, `modules`, `dotnet_tools`, `yazi_plugins`; on Linux
    `brew`, `zsh_plugins`), each a list of strings, items as written in the YAML, deduplicated, in a stable order
    (profiles alphabetical, items in YAML order);
  - `wsl`: the distro name, or an empty string when no selected profile declares one;
  - `profiles`: the selected profile names;
  - `tools`: every selected `scoop` item with the `bucket/` prefix stripped, plus every selected module, `.NET` tool
    and yazi plugin — the names used by "is this tool selected" checks (R16, R19, R22).
- **R10** The output depends only on the YAML and the selection, so it is byte-identical between runs. Install
  scripts rerun exactly when the view part they render changes (verified with a probe source: a change to an
  unselected profile reran nothing; selecting `sdk` reran the Scoop script and the `run_once_` WSL script).

### Packages (`home/.chezmoidata/packages.yaml`)

- **R11** `extras/vscode`, `delta`, `less`, `jq` move to `windows.profiles.base.scoop` (D4); `apps` keeps
  `extras/rider`, `extras/googlechrome`, `extras/postman`, `vagrant`.
- **R12** The header comment drops "ignored until #20" wording and says where the selection is stored and how to change
  it.

### Install scripts (`home/.chezmoiscripts/windows/`)

- **R13** `run_onchange_before_01-scoop.ps1.tmpl` renders buckets and `scoop install` lines from the view's `scoop`; the
  `CI` branch and `$skip` are removed.
- **R14** `run_onchange_before_02-modules.ps1.tmpl` and `run_onchange_before_03-dotnet-tools.ps1.tmpl` render from the
  view's `modules` and `dotnet_tools`.
- **R15** `run_once_after_yazi-plugins.ps1.tmpl` renders from the view's `yazi_plugins`;
  `run_once_before_install-wsl.ps1.tmpl` from the view's `wsl`. A script with nothing to do renders empty, so chezmoi
  does not run it.
- **R16** Rerunning a script with the full list is safe: `scoop install` of an installed app warns and continues,
  `Install-Module` without `-Force` skips an installed module, the .NET tools script installs only missing tools.
  Adding a profile therefore installs only what is new.

### PowerShell profile

- **R17** `Microsoft.PowerShell_profile.ps1.tmpl` imports the view's `modules` only; the `CI` / `$skip` block is
  removed.
- **R18** Tool-specific code moves out of `completers_profile.ps1.tmpl`, `z_inits_profile.ps1`, `psfzf_profile.ps1`
  and `onefetch_profile.ps1` into one fragment per tool, `home/dot_profile/tools/<tool>.ps1[.tmpl]`, named after the
  tool as it appears in `tools` (R9):

  | Fragment | From |
  |---|---|
  | `bat` | completer |
  | `fd` | completer |
  | `ripgrep` | completer |
  | `delta` | completer |
  | `starship` | completer, `Invoke-Starship-TransientFunction`, init, `Enable-TransientPrompt` |
  | `chezmoi` | completer (template: `{{ completion "powershell" }}`) |
  | `dotnet-sdk` | `dotnet` completer |
  | `Terminal-Icons` | `Set-TerminalIconsIcon` |
  | `yazi` | function `y` |
  | `zoxide` | init |
  | `PSfzf` | all of `psfzf_profile.ps1` |
  | `onefetch` | all of `onefetch_profile.ps1` |

  What stays general (aliases `gi`, `file`; the `winget` completer; `_env-variables`, `PSReadLine`, `gitignore`,
  `Write-Pretty`) is always loaded. `_env-variables_profile.ps1` keeps its variables for yazi, ripgrep and fzf: an
  unused variable is inert.
- **R19** A tool fragment is deployed and dot-sourced only when its name is in the view's `tools`: `.chezmoiignore`
  excludes `.profile/tools/<tool>.ps1` otherwise, and the profile template dot-sources only the fragments of selected
  tools. **[added]** The profile today dot-sources by a glob over the *source* folder, so an ignore rule alone would
  leave a dot-source of a file that was never deployed.
- **R20** Load order is kept: general fragments first, then tool fragments, `starship` before `zoxide`, `zoxide` last
  (both hook the prompt; zoxide's docs ask to be initialized last). The "Pofiles hashes" block covers the tool
  fragments too, so `$PROFILE` changes when a fragment changes.
- **R21** `check-updates.ps1.tmpl` renders `Apps` and `Modules` from the view (`tools` of `scoop` items, `modules`).
- **R22** `Complete-UserSetup` renders its WSL part only when the view's `wsl` is not empty; the SSH part is unchanged.

### Claude configuration (D6)

- **R23** When `claude-code` is not in the view's `tools`: `.chezmoiignore` excludes `.claude` entirely and
  `AppData/Local/lazygit/ai-commit.ps1`.
- **R24** `readonly_AppData/Local/lazygit/config.yml` becomes a template; the `<c-a>` custom command renders only when
  `claude-code` is in `tools`. The file uses lazygit's own `{{.Form.Type}}` syntax, so it sets other delimiters with a
  `chezmoi:template:left-delimiter` / `right-delimiter` directive instead of escaping each lazygit expression; the
  rendered file must equal today's file when `claude-code` is selected.

### CI and the VM

- **R25** `home/.chezmoidata/ci.yaml` is removed, with every reference to `ci.skip_scoop_profiles`.
- **R26** `install.ps1` accepts the selection non-interactively and forwards it to `chezmoi init` (R4); without it,
  `chezmoi init` prompts as usual. CI selects `shell`, `sdk`, `ai` with `ai items=claude-code`: no `apps`, no
  `containers`, as today.
- **R27** The VM runner can apply a given selection and can later add a profile with
  `chezmoi init --prompt … --apply`. It installs Pester itself before the tests (D9).

### Tests

- **R28** Static: a test file for the view renders it with fixture configs and checks: no selection → everything
  (R7); a selection → only those profiles plus `base`; a `pick` profile → only the picked items; `global` merged;
  `tools` strips buckets; `wsl` empty without `sdk`. `CiProfiles.Tests.ps1` is replaced by it. A test checks that
  every `home/dot_profile/tools/*` name exists in the full view's `tools`, so renaming a tool in the YAML cannot orphan
  a fragment.
- **R29** Post-apply: `Installed-Apps-Modules.Tests.ps1` takes its expected lists from the view rendered with the
  machine's config; `Profile.Tests.ps1` still loads `$PROFILE` without errors for whatever was selected.

### Removal

- **R30** Deselecting a profile or a pick uninstalls nothing and prints nothing; removal is manual
  (`scoop uninstall`). **[added]** Fragments and the Claude configuration of a deselected tool stay in `$HOME`:
  chezmoi leaves a target in place once it is ignored (verified on v2.73.1). The profile no longer dot-sources them
  (R19), which is what matters.

### Docs

- **R31** `docs/packages.md` (selection, view, "condition on the tool" rule, how to add a profile), `docs/chezmoi.md`
  (`init --prompt`), `docs/conventions.md` (tool fragments replace "a new fragment needs no profile edit" for
  tool-specific code), `docs/testing.md` (CI selection replaces `ci.skip_scoop_profiles`), `docs/architecture.md`,
  `AGENTS.md` Commands (change the selection), then the docs-sync agent regenerates the ReadMe table (profiles change
  for `vscode`, `delta`, `less`, `jq`).

## Open question O1: new items in a `pick` profile

After init, an item added to `apps` or `ai` is in no stored pick, and the next apply does not ask, so it is not
installed and nobody is told.

| Option | Behaviour | Cost |
|---|---|---|
| **A. Notice (recommended)** | The config template also stores `offered.<profile>` (the items shown at the last prompt). A `run_after_` script prints the items of selected `pick` profiles that are not in `offered` and the command `chezmoi init --prompt` | One more data key and a short script, like the admin reminder |
| B. Store exclusions instead of picks | New items install everywhere by default | Contradicts the reason for picks: a new heavy app lands on the work laptop unasked |
| C. Accept it | New items need a manual `chezmoi init --prompt` | Silent; breaks "nothing disappears silently" |

## Non-goals

- Uninstalling on deselection. Linux scripts (#12): the view handles Linux data, no Linux script reads it.
- GitHub Copilot and a configuration shared by AI assistants (follow-up issue).
- Hiding config files of unselected non-AI tools (yazi, lazygit, fzf, starship): inert without the tool.

## Acceptance

- ADR-0005 and this spec committed.
- `chezmoi init` asks for profiles and, for `apps` / `ai`, for items; the answers are stored and not asked again;
  `chezmoi init --prompt` asks again with the stored answers as defaults.
- On the VM as a standard user: `base + shell` applies cleanly; adding `sdk` with `chezmoi init --prompt … --apply`
  installs only `sdk`.
- `$PROFILE` loads without errors for any combination; completers, inits and imports exist only for selected tools.
- Tests derive the expected packages from the selection.
