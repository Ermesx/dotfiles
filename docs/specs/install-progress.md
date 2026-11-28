# Spec: One progress look for every installer and updater

Issue: [#62](https://github.com/Ermesx/dotfiles/issues/62) · Related: [#45](https://github.com/Ermesx/dotfiles/issues/45),
[#47](https://github.com/Ermesx/dotfiles/issues/47) · Status: Draft · Date: 2026-11-28 ·
Plan: [`install-progress.plan.md`](install-progress.plan.md)

## Intent

The apply step prints every line of every tool it runs (Scoop alone prints several lines per app), locally and in the
GitHub Actions log, so the useful signal is buried. The goal is one consistent, compact output for everything the
dotfiles install or update: finished items as one line each, the current item and overall progress on one live line
locally, and the tool's full output only when an item fails.

## Goals, non-goals, anti-goals

| | |
|---|---|
| **Goals** | The same look for the install scripts and the `Update-*` functions. A short log in CI. A readable apply on a machine where almost everything is already installed. Full diagnostics whenever something fails |
| **Non-goals** | Per-download progress (bytes of the current file): Scoop prints it with the same `Write-Host` as every other message, so it cannot be kept on its own. A spinner animation (needs a background job; the counter already shows progress). Parallel installs. Changing what is installed or in which order |
| **Anti-goals** | Hiding a failure: a failed item must always show the tool's own output. Making a cosmetic change rerun the installs on every machine. A copy of the helper in each script |

## Facts this design rests on

Checked 2026-11-28 unless noted.

- Scoop has no quiet option. `scoop install` takes only `-g -i -k -s -u -a`; its messages **and its errors** are
  `Write-Host` (stream 6), so dropping that stream also drops the reason for a failure. Scoop's download bar is shown
  only when `[console]::IsOutputRedirected` is `$false` (`lib/download.ps1`).
- `scoop install` exits 1 (`abort`) when installing a single app fails; with several apps in one call it ends with
  `exit 0`. The exit code is reliable only with one app per call, as the script does now.
- chezmoi runs a `run_onchange_` script **in full** whenever its rendered content (or file name) changes, and records
  it as done only after a successful run. Adding one app reruns every `scoop install` line; most items are already
  present.
- `before_` scripts run before any file, directory or symlink is written (chezmoi docs, *Target types → Scripts*), so a
  module deployed to `~/Documents` does not exist yet on the first apply. The source tree does: `chezmoi init` clones
  it before running scripts.
- For scripts chezmoi sets `CHEZMOI_SOURCE_DIR` to the source root **after** `.chezmoiroot` (here `…/chezmoi/home`);
  `.chezmoi.sourceDir` and `.chezmoi.workingTree` in templates agree (`workingTree` is the repository root). The docs
  do not name this variable, so it was verified on chezmoi 2.73.1 with a scratch source (a script printing its
  environment).
- Scripts run under `pwsh -NoLogo -NoProfile` (`[interpreters.ps1]`), so ANSI sequences are available; `Write-Pretty`
  already relies on that.
- What the install scripts install is the selection of the `packages.tmpl` view (profiles and picks, e.g.
  `DOTFILES_PROFILES`); `CI` does not change it (static test *ignores CI for the selection*). The CI apply installs
  `shell,sdk,ai` with the pick `claude-code`. `install.ps1` passes `--no-tty` to `chezmoi init` only when `CI=true`,
  so a local apply has a terminal (prompts need one) and a runner has none.
- `PackageUpdates` already has one shared update loop, `Invoke-PackageUpdateLoop`, used by the three `Update-*`
  functions; they currently print the tool's full output (`| Out-Host`) between the loop's one-line headers.

## Decisions

| # | Decision | Agreed | Why |
|---|---|---|---|
| D1 | Where the shared code lives | **Agreed 2026-11-28:** a new module (name: D9) next to `Write-Pretty` and `PackageUpdates`, imported by the `before_` scripts from the **source tree** through `$env:CHEZMOI_SOURCE_DIR`, and by `PackageUpdates` from the deployed copy | Rejected: a helper rendered into each script from `.chezmoitemplates/`, because a tweak to the look would change the rendered content of all install scripts and rerun every install on every machine, and because `Update-*` could not share it. Rejected: relying on the deployed module, which does not exist yet on the first apply |
| D2 | Scope | **Agreed 2026-11-28:** all installers (`01-scoop`, `02-modules`, `03-dotnet-tools`) and all three `Update-*` functions | One consistent output |
| D3 | Interactive vs CI | **My call (revised after the builder check):** the live line is used only when `CI` is not `true` **and** the output is not redirected; in every other case the module falls back to plain mode (never a stack of `\r` lines). A parameter overrides both, for tests | `CI=true` is what GitHub sets, and the repo already keys on it (the decryption guard, `--no-tty` in `install.ps1`). Redirection is a safe second condition: if chezmoi pipes script output, the worst case is plain `✓` lines locally, which is still the compact log the issue asks for. Whether chezmoi gives the script a console is observed on the VM and a real terminal (acceptance 1), not assumed |
| D4 | Output of an item | **My call:** every stream captured (`*>&1`) per item, discarded on success, printed in full on failure | The tool's own words are the diagnostics; the live line replaces them on success |
| D5 | Items already present | **My call:** not listed, only counted in the final line | `run_onchange_` reruns the whole list, so a normal apply has 1 new item among ~40 present |
| D6 | A failed item | **Agreed 2026-11-28:** the remaining items still run; the script then exits 1, so `chezmoi apply` stops (files and later scripts are not applied) and the CI step fails | A single failure should not leave the rest of the packages uninstalled. chezmoi records a `run_onchange_` script only after a successful run, so the next apply retries it. Rejected: exit 0 with a summary (outside CI or everywhere): the failed item would not be retried until the script content changes, and CI would not catch a broken install. Today only the last command decides the script's exit code, so a failure in the middle of the list is silent |
| D7 | Scope exclusions | **My call:** WSL distro install stays as is | One conditional, one-off item whose own `wsl --install` progress is the useful output; nothing to count or collapse |
| D8 | Yazi plugins | **My call:** included | Already a list with a presence test; fits the same mechanism |
| D9 | Module name | **My call:** `StepProgress`, one public function `Invoke-ProgressSteps` | Names the job (run a list of steps with progress), not the tools |
| D10 | Who decides that an item failed | **My call:** `Invoke-ProgressSteps`. An item failed when its action throws, or when `$LASTEXITCODE` is non-zero after it (the module resets it to 0 before each action) | Callers stay thin: a script is the item list plus one line per tool; the `Update-*` blocks lose their `$LASTEXITCODE -eq 0` and `\| Out-Host` boilerplate. Scoop's `abort` is a non-zero exit code, `Update-Module` is called with `-ErrorAction Stop` |
| D11 | One-time rerun | **My call:** accepted. The first apply after this change rerun all install scripts on every machine, because their rendered content changes once | Unavoidable for any change to those scripts; with D5 the rerun is cheap (everything is present) and CI is a clean machine anyway. Later changes to the look do not rerun anything (D1) |
| D12 | Presence by name | **My call:** the presence test compares names only; `packages.yaml` has no version-pinned (`@`) entries today | Installing an already-installed item does nothing in Scoop and `dotnet tool install` either, so no behaviour is lost. If a pinned entry is ever added, the test must compare versions; noted so it is not forgotten |
| D13 | Import mechanism | **My call:** every script, `before_` and `after_` (the yazi plugins script too), imports from `$env:CHEZMOI_SOURCE_DIR` | One mechanism, and the `after_` scripts do not depend on the deployed copy either |

## Requirements

### Module `StepProgress`

Layout as `Write-Pretty` and `PackageUpdates`: `.psd1` with an explicit `FunctionsToExport` list, `.psm1` that
dot-sources `private/` and `public/`, one function per file. **No templates (`.tmpl`) in the module**: the scripts
import it from the source tree, where nothing is rendered. Independent of `Write-Pretty` (it is not available yet on
the first apply either); it writes its own ANSI sequences.

- **R1 Public interface.** `Invoke-ProgressSteps` takes: a title; the items; a way to get an item's display name; an
  optional presence test; the action that installs or updates one item; an optional detail text per item (for
  updates: `old → new`); and the mode (live or plain; default from `CI`, D3). It returns an object with the counts
  (`Done`, `Present`) and the failed items with their captured output, so a caller can act on them. The exact
  parameter names are the builder's call. Failure is decided by the module (D10); the captured output must never mix
  with the success result.
- **R2 Header.** Prints `► <title>` in cyan, in the style of the existing scripts.
- **R3 Finished item.** One permanent line: `✓ <name>  [<detail>]  <duration>` color: default; for a failure `✗ <name>`
  followed by
  the captured output of the item, indented. Durations are rounded to 0.1 s, color: red.
- **R4 Live line (interactive).** While an item runs, the last line shows a bar, `N/M` and the item name, redrawn in
  place (carriage return, clear-to-end-of-line); the finished line replaces it and a new live line starts below. `N`
  counts items to run, not items present (D5), so `M` is the number of items that will actually run. Truncated to the
  terminal width (80 when unknown). The cursor is left on a clean line on success, failure and Ctrl+C.
- **R5 Plain mode (CI).** The same finished lines and header, no live line, no cursor control, **no control
  characters at all** (colour included), so the log is greppable. The colours of R2 and R3 apply to live mode only.
- **R6 Presence (D5).** Items for which the presence test is true are not run and not listed. Final line: `✓ N
  installed, M already present` (updates: `updated`), `✓ M already present` when nothing ran, `✓ N installed in 1m 12s`
  when nothing was present; **no final line when exactly one item ran, succeeded and nothing was present** (it would
  repeat the item line, e.g. the single "Scoop and buckets" step of `Update-Apps`). The test is cheap: a single query per installer, not one process per item (see R10).
- **R7 Failure (D6).** After the last item: the failed names as one summary line. The caller exits non-zero.
- **R8 No side effects on import.** Importing prints nothing and changes no preferences, so the thread job of
  `Check-Updates` can load `PackageUpdates` without noise.

### Install scripts

- **R9 Import (D13).** Each install script, `before_` and `after_` alike, starts with a single import of the module from `$env:CHEZMOI_SOURCE_DIR` (not from the
  template variable, so the rendered script content does not contain a machine path; a different checkout location
  would otherwise change the hash and rerun the script). No tool or file guards: a missing module is a bug and fails
  the script loudly.
- **R10 Presence queries, one per installer** (the builder confirms the exact query on a real machine):
  - Scoop: the set of installed app names from one `scoop` call, compared with the item name without its `bucket/`
    prefix, case-insensitive.
  - Modules: `Get-InstalledModule` once, by name.
  - .NET tools: `dotnet tool list -g` once, by package id (case-insensitive).
  - Yazi plugins: the existing `ya pkg list` match, moved into the presence test.
- **R11 Scoop buckets.** `scoop bucket add` keeps working as before; it prints one line per bucket and is not
  wrapped unless the builder finds it equally noisy in the CI log.
- **R12 Behaviour that must not change:** which items are installed, the order (`01` → `02` → `03`), the
  selection of the `packages.tmpl` view (`CI` does not change it), the `PATH` refresh at the top of the .NET tools script, `Set-PSRepository`
  trusting the Gallery, the `Pester` special case (inbox Pester 3.4 is signed by another publisher).
- **R13 Exit code.** A script that had failed items exits non-zero (D6); one that had none exits 0 even when the last
  native command inside returned non-zero (under `pwsh <file>` the process exit code otherwise follows the success of
  the last command only, so an earlier failure is invisible today). The scripts therefore end with an explicit
  `exit`.

### `PackageUpdates`

- **R14** `Invoke-PackageUpdateLoop` uses `Invoke-ProgressSteps` for display and keeps its job: update each row, keep
  going after a failure, leave only the failed rows in the cache section. The row's `Old`/`New` become the detail.
  `PackageUpdates` declares the new module as a required module, imported from the deployed copy.
- **R15** The tool output of `scoop update <app>`, `Update-Module` and `dotnet tool update` is captured, not sent to
  `Out-Host`; shown only on failure. `scoop update` for Scoop itself and the buckets is one step with one line.
- **R16** `Update-Apps` keeps its second check (an app with a running process is skipped by Scoop and still exits 0,
  so the state after the loop, not the exit code, decides what is left) and its `Not updated: …` message.

### CI and docs

- **R17** `.github/workflows/ci.yml` adds the module's test folder to the Pester paths of the unit-test step.
- **R18** Docs: `docs/testing.md` (module test path, same `PSModulePath` prefix rule as for the other modules);
  `docs/chezmoi.md` or `docs/conventions.md`, where the install scripts are described: one line on the shared module and
  on why scripts import it from `CHEZMOI_SOURCE_DIR`; `AGENTS.md` if it lists the modules.

## Approaches considered

| Approach | Verdict |
|---|---|
| A. Helper rendered into each script from `.chezmoitemplates/` | Rejected (D1): a cosmetic change reruns all installs everywhere; not usable by `Update-*` |
| B. A copy of the helper in each script | Rejected: three copies drift; consistency is the goal |
| **C. A module imported from the source tree by the `before_` scripts, and from the deployed copy by `PackageUpdates`** | **Chosen by the owner, 2026-11-28** |

Within C, rejected: `6>$null` on `scoop install` (hides the cause of a failure); matching the text "already
installed" in Scoop's output (breaks on a wording change; a presence query does not).

## Constraints

- Windows only (the Linux scripts are out of scope). Security rules unchanged: nothing here touches secrets or
  decryption, and the CI rule (nothing decrypted in CI) is unaffected.
- The module must work under `pwsh -NoProfile` in a process that has loaded nothing else from the dotfiles.
- A module imported by path and the same module deployed to `~/Documents` are two copies of the same files; scripts
  run in a fresh process, so they never meet. A test must import the module from the working copy, not the installed
  one (`docs/testing.md`, *Unit tests against the working copy*).

## Acceptance criteria

1. **First apply on a clean machine** (VM, standard user): the install scripts find the module in the source tree;
   the output is the lines of R3 plus a live line; no tool output unless an item fails.
2. **Second apply with one new package:** the new item as one line and `✓ 1 installed, N already present`; nothing
   else.
3. **CI log:** one `✓` line per installed item, no control characters; a deliberately failing item (a temporary test
   branch, not committed) shows the tool's full output and fails the step.
4. **`Update-Apps`, `Update-Modules`, `Update-DotnetTools`:** same look; a failed update shows the tool's output and
   stays in the cache section, as today.
5. **Changing only the look** (a module file) does not change the rendered content of any install script.
6. Pester tests of the module pass on the host and in CI (see Tests).

## Tests

- **Module (Pester, `tests/windows/StepProgress`)**, on captured host output, with fake items and actions: finished
  and failed lines; counts and the final line for all-new, mixed, all-present and all-failed lists; plain mode
  contains no ESC character; live mode ends on a clean line; a failing action does not stop the next item; captured
  output appears only for a failed item; the width truncation.
- **Static (`tests/static`):** every install script renders and starts with the import from `CHEZMOI_SOURCE_DIR`; the
  rendered script content contains no absolute source path (R9); the module contains no `.tmpl`.
- **`PackageUpdates` tests** (`tests/windows/PackageUpdates/Update.Tests.ps1`): adapted to the new output; the
  behaviour they already check (continue after a failure, failed rows stay in the cache) must still hold.
- **Not covered by automation:** the redraw under a real chezmoi on a real terminal. Verified by hand on the VM and a
  real `chezmoi apply` before merge.

## Open and left to the builder

- Exact presence queries (R10), in particular whether `scoop list` output is object-shaped on the pinned Scoop
  version; verify on a machine with Scoop.
- Whether chezmoi hands the script a real console. The owner states it does (a script may need to interact with the
  user), so D3 stands; still observed on the VM (acceptance 1). If it does not, the redirection check of D3 degrades
  the live line to plain mode.
- Bar glyphs and the spinner glyph in the live line, for a console font without them (fallback to ASCII).
- Whether `scoop bucket add` needs the same treatment (R11).
