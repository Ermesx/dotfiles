# Spec: Three-layer testing — static, GitHub Actions, standard-user VM

Issue: [#47](https://github.com/Ermesx/dotfiles/issues/47) · ADR: none (see D9) · Status: Accepted · Date: 2026-11-22 ·
Plan: [`three-layer-testing.plan.md`](three-layer-testing.plan.md)

Today the only full test is the Vagrant VM; there is no CI. This spec turns the issue into requirements, corrects what
the issue got wrong after reading the code (marked **[added]**), and maps every scope item and acceptance criterion
to a requirement, to "already done", or to a later issue.

## Facts checked on 2026-11-22 (chezmoi v2.73.1)

State of `develop` **before** this change. After D1 the two decrypting lines live in
`home/dot_config/git/user.gitconfig.tmpl` (target `.config/git/user.gitconfig`), and `dot_gitconfig.tmpl` (target
`.gitconfig`) no longer decrypts; the CI list is in D2 and `docs/testing.md`.

- Decryption points in `home/` (by consumer, not only by grep): `dot_ssh/encrypted_id_ed25519.age`,
  `dot_ssh/encrypted_id_ed25519.pub.age`, `dot_gitconfig.tmpl` lines 2–3 (`include | decrypt` of
  `.encrypted-data.toml.age` and the public key), the two `run_onchange_before_decrypt-private-key` scripts
  (`chezmoi age decrypt --passphrase`), and **[added]** `run_once_after_add-ssh-key.ps1`, which consumes the
  decrypted private key. `.key.txt.age` and `.encrypted-data.toml.age` start with a dot, so chezmoi never deploys them.
- Target names (what `.chezmoiignore` matches): `.ssh/id_ed25519`, `.ssh/id_ed25519.pub`, `.gitconfig`,
  `.chezmoiscripts/windows/decrypt-private-key.ps1`, `.chezmoiscripts/linux/decrypt-private-key.sh`,
  `.chezmoiscripts/windows/add-ssh-key.ps1`, `.chezmoiscripts/windows/install-wsl.ps1`.
- `decrypt` with no usable identity fails the render (`error calling decrypt`), so a runner without a key cannot
  decrypt by accident. A check run on the host, where `~/.config/chezmoi/key.txt` exists, **would** decrypt: every
  host check therefore runs chezmoi with `--config <temp>` whose `[age] identity` points to a file that does not exist.
- Every `*.tmpl` except `dot_gitconfig.tmpl` renders with `execute-template` today.
- `chezmoi managed --include=all --path-style source-relative` lists the source path of every target the current
  `.chezmoiignore` keeps.
- Scoop's known buckets are in `https://raw.githubusercontent.com/ScoopInstaller/Scoop/master/buckets.json`. A
  manifest is at `https://raw.githubusercontent.com/<owner>/<repo>/HEAD/bucket/<app>.json`: 200 for every item in
  `packages.yaml` today, 404 for `main/no-such-app-xyz`. No API, no token, no rate limit that matters here.
- Pester 6.2.0 is the latest in PSGallery. The Scoop installer has `-RunAsAdmin`; `irm get.scoop.sh | iex` cannot
  pass it, the scriptblock form `& ([scriptblock]::Create((irm get.scoop.sh))) -RunAsAdmin` can.
- `.chezmoi.toml.tmpl` has no prompts (profiles are #20), so `chezmoi init` needs no `--prompt*` answers today.
- `tests/windows/Installed-Apps-Modules.Tests.ps1` already checks `scoop list` / `Get-InstalledModule` against
  `chezmoi data`; no DSC or winget code is left in `tests/` (`git grep -i -E 'dsc|winget' -- tests` is empty).
  The helper view `.chezmoitemplates/packages.tmpl` named in #43 was never built.
- `docs/testing.md` exists, and every link in `AGENTS.md` resolves.

## Decisions

### Confirmed in the issue (2026-11-18)

| # | Decision |
|---|---|
| C1 | Three layers: static (local + CI, every change), GitHub Actions `windows-latest` (PRs to `develop` and pushes), VM as a standard user (before large changes) |
| C2 | **Never decrypt anything in CI.** No age identity, passphrase or key in secrets, variables or workflow files; CI skips every part that needs decryption, keyed on the `CI` environment variable. No exceptions |
| C3 | Windows Sandbox is not an option (Windows 11 Home) |
| C4 | The CI layer runs elevated (`-RunAsAdmin`) and does not prove "no admin"; the VM layer does |

### Confirmed for this spec (2026-11-22): D1–D9

| # | Question | Agreed | Why | Rejected alternative |
|---|---|---|---|---|
| D1 | The issue asks both for a *template guard* in `dot_gitconfig.tmpl` and for a guard test that fails on any non-ignored template *containing* `decrypt`; both cannot hold | **Split:** the two decrypting lines move to a new template `home/dot_config/git/user.gitconfig.tmpl` (target `~/.config/git/user.gitconfig`, a `[user]` section). `dot_gitconfig.tmpl` gets `[include] path = ~/.config/git/user.gitconfig` and no `decrypt`. CI ignores the new target. Git skips a missing include file silently | The guard stays a literal text rule with no exemptions; `.gitconfig` itself is still deployed and tested in CI | `{{ if not (env "CI") }}` around the lines plus a guard exemption (a parser for guarded blocks, or an allowlist a reviewer must keep right); a behavioural guard only (render with no identity) — kept as a second line of defence, not the rule |
| D2 | What CI ignores | One block in `home/.chezmoiignore` under `{{ if env "CI" }}`, in two commented groups: **needs decryption** — `.ssh/id_ed25519`, `.ssh/id_ed25519.pub`, `.config/git/user.gitconfig`, `.chezmoiscripts/windows/decrypt-private-key.ps1`, `.chezmoiscripts/linux/decrypt-private-key.sh`, `.chezmoiscripts/windows/add-ssh-key.ps1` (uses the decrypted key); **runner cannot** — `.chezmoiscripts/windows/install-wsl.ps1` (hosted runners have no WSL distro support; a download attempt would hang or fail) | Each target maps to a reason; the two groups differ in nature (C2 vs. a runner limit) | Ignoring `.ssh/` as a whole (drops more than needed, silently) |
| D3 | Guard rule | With `CI` set, no target in `managed --include=files,scripts,symlinks --path-style source-relative` may have a source name containing `encrypted_`, and no managed file (template, script or plain file) or file under `.chezmoitemplates/` may contain the word `decrypt` — a plain script can run `chezmoi age decrypt` too. Plus: the set of targets ignored only because of `CI` must equal the D2 list exactly | Turns C2 into a check; the set equality catches an over-broad pattern | Grep of the whole `home/` (would flag the ignored scripts) |
| D4 | Where the static checks live | `tests/static/StaticChecks.psm1` with functions that take a source, data or file path, and Pester files in `tests/static/` that run each function twice: against the repo (expect nothing) and against `TestDrive:` fixtures (expect the planted fault) | AC2 and AC3 become provable on the host without breaking the real source | Checks only against the repo (green proves nothing about red) |
| D5 | Scoop item check | Item `bucket/app` or `app` (= `main/app`); the bucket must be a key of Scoop's `buckets.json`; the manifest URL from *Facts* must return 200; only 404 means "no manifest", other statuses retry twice and report a network error | Mirrors what the install script does (`scoop bucket add <name>` works only for known buckets); no token | `scoop info` (needs Scoop and added buckets; slow); GitHub API (rate limit, `GITHUB_TOKEN`) |
| D6 | Workflow shape | **One job** on `windows-latest`, steps in this order: assert no identity → Scoop → chezmoi + Pester 6 → static and unit tests → `chezmoi init --apply` → post-apply tests → assert no identity. A failing static step stops the job before the slow apply | Fewer moving parts than two jobs that each install Scoop and chezmoi | Separate static job on `ubuntu-latest` (renders with `.chezmoi.os = linux`, misses the Windows templates) |
| D7 | Scoop download cache | Not at first. Measure the apply step on the first green run; add `actions/cache` for `~/scoop/cache` keyed on `hashFiles('home/.chezmoidata/packages.yaml')` only if the step takes more than 15 minutes | Complexity must pay for itself | Cache from day one |
| D8 | VM standard user | The Vagrant provisioner creates a local standard user `dotfiles` (member of `Users` only) with password `dotfiles`, and syncs the repo root a second time to the neutral `C:/dotfiles-src`. The person logs in to the VM window as that user and runs `run-tests.ps1`, which copies `C:\dotfiles-src` to `~\.local\share\chezmoi` (working copy, uncommitted changes included) when that folder is missing. Interactive on purpose: the key passphrase prompt needs a person | A synced folder under `C:\Users\<new user>` before the first login makes Windows create the profile under another folder name; the existing sync sits in `vagrant`'s profile, which a standard user cannot read. The password protects a throwaway local VM, like the box's own `vagrant`/`vagrant` | Running as that user from the admin session via a scheduled task (non-interactive, cannot answer the passphrase) |
| D9 | ADR | None: test infrastructure, no change to how the dotfiles work. The decisions live here | An ADR per CI choice is ceremony | ADR-0005 |

### Amended in the branch code review (2026-11-22)

- D2: the block is `{{ if eq (env "CI") "true" }}`, so a stray `CI=1` on a real machine keeps the identity managed.
- D3: "contains `decrypt`" means a decrypt **call** — `{{ … decrypt … }}` or `chezmoi age decrypt` — not the bare
  word in names or comments; and chezmoi's own files (config template, data, externals, ignore files, shared
  templates) are scanned too, since CI renders them although they are not targets.
- R6 step 7 also fails on `~/.config/git/user.gitconfig` and reads git with `--includes`.

### Changed by the owner before review (2026-11-22)

- D7 replaced: measured on the first green run, Scoop took ~11 min of the 14.5-min apply, of which downloads ~1.5
  min and extraction/install ~9 min. Chosen: skip the heavy `apps` profile in CI via `ci.skip_scoop_profiles` in `home/.chezmoidata/ci.yaml` (CI=true only;
  the static layer still checks those manifests, the VM installs them). Rejected: caching installed apps (CI would
  stop testing the install, and app env vars such as `DOTNET_ROOT` would need restoring); caching `~/scoop/cache`
  (tried: with a warm 1.3 GB cache apply took 4m10s vs 4m03s cold, plus 15 s restore — removed).
- Every CI step runs with `pwsh -NoProfile` (custom default shell with the built-in shell's Stop preference and
  exit-code handling), so post-apply steps do not load the installed profile.

## Requirements

### CI mode in the chezmoi source

- **R1** (D1) `home/dot_config/git/user.gitconfig.tmpl` (LF) holds `[user]` with the two lines moved verbatim from
  `dot_gitconfig.tmpl` (`.encrypted-data.toml.age` indented, `signingkey = …`). `dot_gitconfig.tmpl` drops them
  and starts with `[include]` / `path = ~/.config/git/user.gitconfig`. On the host, `git config user.name`,
  `user.email` and `user.signingkey` return the same values before and after (checked on the VM; never apply on the
  host).
- **R2** (D2) The CI block in `home/.chezmoiignore`, after the OS branches, with a comment per group naming the
  reason and pointing to `docs/testing.md`.

### Static layer (`tests/static/`, runnable on the host and in CI)

- **R3** `StaticChecks.psm1` (CRLF) exports, each returning an empty array when all is well:
  - `Get-TemplateRenderFailure -Source <repo root>` → `[pscustomobject]@{ Path; Error }` for every template that
    fails `execute-template` with `CI=true`: every `*.tmpl` under the root, managed or CI-ignored, except those
    containing `decrypt` (the guard keeps them out of CI); files under `.chezmoitemplates/`; every
    `.chezmoiignore`; and `.chezmoi.toml.tmpl` (rendered with `--init`).
  - `Get-CiDecryptionViolation -Source <repo root>` → source-relative paths breaking D3's first sentence.
  - `Get-CiIgnoredTarget -Source <repo root>` → targets in `managed --include=files,scripts,symlinks` without `CI`
    minus those with `CI=true`, sorted (directories left out: whether one is listed depends on its children).
  - `Get-PackagesData -Source <repo root>` → the `packages` node of `chezmoi data --format json`.
  - `Get-ScoopItemProblem -Item <string[]>` → `[pscustomobject]@{ Item; Problem }`, `Problem` is
    `'unknown bucket'`, `'no manifest'` (HTTP 404 only) or `'network error <status>'` (anything else after two
    retries) (D5).
  - `Get-PackagesSchemaProblem -Packages <object>` (the `packages` node of `chezmoi data --format json`) → one
    message string per fault: platform other than `global` / `windows` / `linux`; a platform key other than
    `profiles`; a method not allowed on its platform (`global`: `dotnet_tools`, `yazi_plugins`; `windows`: `scoop`,
    `modules`, `wsl`; `linux`: `brew`, `zsh_plugins`); `pick` anywhere but directly on a profile, or not a boolean;
    `wsl` not a single string; any other method not a list of strings.
  - `Get-BrokenMarkdownLink -Path <md file>` → relative link targets in the file that do not exist.
  Every chezmoi call uses `--config` pointing to one temp `.toml` file with `encryption = "age"`, an
  `[age] identity` that does not exist and `[warnings] configFileTemplateHasChanged = false`; reads stdout only;
  and sets `CI=true` — or, for the "without CI" side of `Get-CiIgnoredTarget`, removes `CI`, which GitHub sets for
  the whole job — only in its own scope, restored afterwards.
- **R4** Pester 6 files, each with `#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '6.0.0' }`:
  `Templates.Tests.ps1`, `NoDecryptInCi.Tests.ps1`, `Packages.Tests.ps1`, `Docs.Tests.ps1`. Each check runs against
  the repo (empty result) and against a fixture (the planted fault is reported). `NoDecryptInCi` also asserts
  `Get-CiIgnoredTarget` equals the D2 Windows list (the Linux script is already ignored on Windows by `**/*.sh`).
  `Docs` checks `AGENTS.md` and `docs/testing.md` exist with no broken links.

### CI layer (`.github/workflows/ci.yml`)

- **R5** Triggers: `pull_request` to `develop`, `push` to `develop`, `workflow_dispatch`. `permissions: contents:
  read`. No `secrets.*`, no `vars.*`, no `env` holding a key. `actions/checkout@v4` with `persist-credentials:
  false`. `timeout-minutes: 90`. Shell `pwsh`.
- **R6** Steps (D6): (1) fail if `~/.config/chezmoi/key.txt` exists; (2) install Scoop with `-RunAsAdmin`, add
  `~/scoop/shims` to `GITHUB_PATH`; (3) `scoop install chezmoi`; `Install-Module Pester -MinimumVersion 6.0.0
  -Scope CurrentUser -Force -SkipPublisherCheck`; (4) Pester `tests/static` and the unit folders
  (`tests/windows/Write-Pretty`, `tests/windows/PackageUpdates`, `tests/windows/AdminSetup`, with the
  `PSModulePath` prefix from `docs/testing.md`), failing the step on any failure; (5) `chezmoi init --apply --source
  $env:GITHUB_WORKSPACE --no-tty`; (6) refresh `PATH` from the registry, then Pester
  `tests/windows/Installed-Apps-Modules.Tests.ps1` and `tests/windows/Profile.Tests.ps1`; (7) fail if
  `~/.config/chezmoi/key.txt` or `~/.ssh/id_ed25519` exists, or if `git config --global --get user.signingkey` or
  `user.email` returns anything (the git identity never reaches CI). CI never runs `install.ps1` (it clones `Ermesx`'s
  default branch, not the PR); the VM covers it.
- **R7** **[added]** `tests/windows/Profile.Tests.ps1`: starts `pwsh -NoLogo -NoProfile -Command '. $PROFILE'`
  with `2>&1`; passes when the exit code is 0 and no error record was written. It does not count `$Error`, which
  also holds errors silenced on purpose (`-ErrorAction SilentlyContinue` probes in `check-updates.ps1.tmpl`). Post-apply only (the
  profile imports modules and calls tools that exist only after apply); runs in CI and in the VM. Profile
  combinations follow #20.

### VM layer (`tests/`)

- **R8** (D8) `tests/Vagrantfile`: a PowerShell provisioner that creates the user idempotently and the second synced
  folder `..` → `C:/dotfiles-src`. `tests/run-tests.ps1`: before the install, when
  `~\.local\share\chezmoi` is missing and `C:\dotfiles-src` exists, create its parent and copy it there. Start
  the VM from the main checkout, not a worktree (a worktree's `.git` is a file pointing to a host path). Behaviour for the `vagrant`
  account is unchanged.

### Docs

- **R9** `docs/testing.md` rewritten: the three layers (table: what, where, when, command), how to run the static
  layer on the host, what CI does and that it does not prove "no admin", the no-decryption rule with the D2 list and
  how to add a new decryption point (add the target to the CI block; the guard test fails until then), and the VM
  standard-user procedure. `AGENTS.md` Commands: a "Static tests" row. `docs/chezmoi.md` Encryption: the git user
  include and the CI block. `docs/architecture.md` testing row: `tests/static`, `ci.yml`, Vagrant.

## Scope map

| Issue item | Where |
|---|---|
| CI mode, decryption points | R1, R2 (D1, D2; `add-ssh-key` added) |
| Guard test; workflow asserts no identity | R3, R4, R6 steps 1 and 7 |
| Static: render every template | R3 `Get-TemplateRenderFailure` |
| Static: Scoop items exist | R3 `Get-ScoopItemProblem` (D5) |
| Static: schema | R3 `Get-PackagesSchemaProblem` |
| Static: profile loads | R7 — post-apply, not static (needs installed modules); combinations → #20 |
| `ci.yml` with Scoop `-RunAsAdmin`, non-interactive init, Pester, timing/cache | R5, R6, D7; `--prompt*` answers → #20 |
| VM: standard user | R8 |
| VM: old winget set (#46 scenario) | Deferred to #46 (optional in the issue) |
| Replace DSC test logic | Already done by #43 (Facts); the helper view was never built and is not built here |
| `docs/testing.md` | R9 (exists; content rewritten) |
| AC1 CI on PRs, no secret, green | R5, R6; green run on the PR |
| AC2 broken template / missing package fails static | R4 fixtures |
| AC3 no decryption; deliberate attempt fails | R2–R4, R6; plus one temporary commit on the PR (Acceptance 4) |
| AC4 VM standard user passes | R8; Acceptance 5 (by hand) |
| AC5 `docs/testing.md`, AGENTS links | R9, R4 `Docs.Tests.ps1` |

## Non-goals

Profile selection and its `--prompt*` answers (#20); the migration scenario (#46); Linux CI (#12); proving "no
admin" in CI (C4); a Scoop cache before measuring (D7).

## Acceptance

1. **Host:** Pester `tests/static` passes against the repo; each fixture test reports its fault; no host check
   decrypts (temp config). [AC2, AC3]
2. **Host:** `chezmoi --source . managed --include=all` is unchanged except `.config/git` and `.config/git/user.gitconfig` added;
   `git grep -n decrypt -- home` lists only the two decrypt scripts and `user.gitconfig.tmpl`.
3. **PR:** the `ci` workflow is green on the PR to `develop`; `ci.yml` contains no `secrets.` or `vars.`; the
   apply step's duration is in the PR description (D7). [AC1]
4. **PR:** a temporary commit adds `home/dot_leak.tmpl` containing `{{ "x" | decrypt }}`; the run fails in the static
   step (`NoDecryptInCi`); the commit is reverted. [AC3]
5. **VM, standard user `dotfiles`:** `vagrant up dotfiles-windows --provision` (`vagrant reload --provision` on an
   existing VM); log in as `dotfiles`;
   `C:\vagrant\run-tests.ps1 -BRANCH <branch>` passes with no UAC prompt; `git config user.name` and `user.email` are set and a signed commit verifies (never
   print `user.signingkey`). [AC4]

## Risks

- First-run unknowns on `windows-latest`: total apply time (Rider, VS Code, Chrome, .NET SDK), whether every Scoop
  app installs on Windows Server, and whether `Stop-Process explorer` in `user-settings` matters there. The first
  run decides; a failing app is a finding for the PR, not a reason to skip it silently.
- The profile may write non-terminating errors on a runner that has no prior state (e.g. Check-Updates cache); R7
  prints them, the PR records any fix.
- `chezmoi managed` on a fixture with an `encrypted_` file may try to read the ciphertext; if it errors, the fixture
  uses a source-name scan only (plan Task 1 Step 4 reveals it).
- `install-wsl.ps1` already skips itself when `wsl --status` fails; its D2 entry assumes the runner might pass that
  probe and then try a download. If the first run shows `wsl --status` fails on `windows-latest`, the entry can be
  dropped in a follow-up (the template is rendered by R3 either way).
- `vboxsf` share permissions for a standard user and the copy of `.git` from the share are unverified until the VM run.
