# Rancher Desktop instead of Docker Desktop Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

> **State (2026-11-24):** Tasks 1–5 done on `feat/48-container-engine` (PR #58): `10b9b0b` and the review-fix
> commits. Open: Task 6 (real machine).

**Goal:** Rancher Desktop (moby) from Scoop replaces Docker Desktop as the only container engine and docker CLI,
without admin; started on demand, updating itself.

**Architecture:** Data only, no new scripts: a `containers` profile in `packages.yaml` feeds the existing Scoop
install template; a `create_` file seeds Rancher's `settings.json` once; CI skips the profile through
`ci.skip_scoop_profiles`; the profile template imports modules only of installed profiles, by the same rule. Static Pester
tests pin what a future edit could silently break.

**Tech Stack:** chezmoi (source attributes, templates), Scoop (`extras` bucket), Rancher Desktop 1.25.0, Pester 6.

**Spec:** [`container-engine.md`](container-engine.md) (D1–D9, F1–F8, R1–R11, A1–A7).

## Global Constraints

- Branch `feat/48-container-engine` off `develop`; Conventional Commits with a scope; PR #58 carries `Fixes #48`.
- Never run `chezmoi apply`, `install.ps1`, `scoop` or Rancher on the host. Host checks: Pester, template render,
  `chezmoi --source . managed`.
- `*.ps1`, `*.ps1.tmpl`: CRLF in the working tree; `*.json`, `*.md`, `*.yaml`: LF.
- Static tests use `tests/static/StaticChecks.psm1`: `Get-PackagesData` (exported); `Get-ManagedPath` and
  `Invoke-ChezmoiCi` (not exported) through `InModuleScope StaticChecks` — CI mode, no decryption.
- Static test command: `pwsh -NoProfile -Command 'Import-Module Pester -MinimumVersion 6.0.0; Invoke-Pester tests/static -Output Detailed'`.
- Seed (R4): exactly `version` 19, `containerEngine.name` `moby`, `kubernetes.enabled` false; no `application` key.

## Review Focus

1. **Seed without `version`** → Rancher refuses to start. Pinned in Task 3.
2. **A docker client re-added to Scoop** → two CLIs. Pinned in Task 1.
3. **`containers` dropped from the CI skip list** → ~711 MB per CI run. Pinned in Task 1.
4. **Module filter removed from the profile template** → `DockerCompletion` imported where `containers` was not
   installed (fails once #20 leaves it uninstalled). Pinned in Task 2; `tests/windows/Profile.Tests.ps1` loads the
   profile in CI.
5. **Rancher's updater installs a second copy** (R-1) → not testable here; A5 in Task 6.

---

### Task 1: Packages and CI skip (R1–R3)

- [x] `containers` profile (`extras/rancher-desktop`, `lazydocker`, `DockerCompletion`); docker clients removed from `sdk`.
- [x] `skip_scoop_profiles: [apps, containers]`.
- [x] `ContainerEngine.Tests.ps1` › `one docker CLI`: no `docker`, `docker-compose`, `docker-buildx` in any `windows`
  Scoop list; `containers.scoop` contains `extras/rancher-desktop`, `containers.pick` empty.
- [x] `CiProfiles.Tests.ps1`: `installs no container app when CI is true`, `installs Rancher Desktop on a real machine`.

### Task 2: Profile imports only installed profiles (R10)

- [x] `Microsoft.PowerShell_profile.ps1.tmpl`: `$skip` = `.ci.skip_scoop_profiles` when `CI=true` (as in
  `run_onchange_before_01-scoop.ps1.tmpl`); `range $name, $profile`, modules only when `not (has $name $skip)`.
- [x] `ContainerEngine.Tests.ps1` › `PowerShell profile`: with CI no `Import-Module -Name 'DockerCompletion'` and
  still `posh-git`; without CI `DockerCompletion` imported.

### Task 3: Settings seed (R4, R5)

- [x] Seed with the three keys (D5); `application` removed (D6, D7).
- [x] `ContainerEngine.Tests.ps1` › `Rancher settings seed`: managed source path `…/create_settings.json`; the three
  values; no `application` key; no managed `.docker*` target.

### Task 4: Docs (R6–R8)

- [x] ADR-0004 (seed, on-demand start, self-update exception, module filter, consequences), this spec and plan,
  `docs/packages.md`, `docs-sync` order, ReadMe table.
- [x] `ContainerEngine.Tests.ps1` › `ReadMe package table`: Rancher row under `containers`, no docker client rows.

### Task 5: Tests bite, issues

- [x] Injected `skip_scoop_profiles: [apps]`, `- docker` in `sdk`, no `version`, module filter disabled → exactly
  the matching tests failed; files restored.
- [x] #46: migration steps (before/after apply).
- [x] #48: `Resolution` section on top, original text kept below.
- [x] #20: comment — module imports and `Check-Updates` lists must follow the selected profiles.

### Task 6: Real-machine acceptance (A1–A7)

Private machine, after #46's "before apply" steps, as a standard user; record results in PR #58 and tick them in the spec.

- [ ] A1 no autostart; no first-run dialog; `rdctl list-settings` values.
- [ ] A2 one `docker` on PATH; compose and buildx work.
- [ ] A3 `hello-world`; compose `nginx` on `localhost:8080` → 200.
- [ ] A4 `Testcontainers.PostgreSql` test passes without `DOCKER_HOST`.
- [ ] A5 after Rancher's own update: one copy or two (R-1).
- [ ] A6 `Update-Apps` with Rancher running: others update, Rancher reported as not updated.
- [ ] A7 CI: `Profile.Tests.ps1` loads the profile with `containers` skipped (checked on PR #58).
