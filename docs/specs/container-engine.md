# Spec: Rancher Desktop instead of Docker Desktop

Issue: [#48](https://github.com/Ermesx/dotfiles/issues/48) · ADR: [ADR-0004](../adr/0004-container-engine.md) ·
Status: Draft · Date: 2026-11-24

## Requirements

- **R1** `packages.yaml`: profile `windows.profiles.containers` = `scoop: [extras/rancher-desktop, lazydocker]`,
  `modules: [DockerCompletion]`; `docker`, `docker-compose`, `docker-buildx`, `lazydocker`, `DockerCompletion` removed
  from `sdk`. Linux `sdk.brew: [docker]` unchanged (#12).
- **R2** `home/.chezmoidata/ci.yaml`: `skip_scoop_profiles: [apps, containers]` (~700 MB installer; no engine in CI).
- **R3** `home/readonly_AppData/Local/rancher-desktop/create_settings.json`: `version` 19 (required by Rancher 1.25),
  `application.autoStart` and `application.startInBackground` true, `application.updater.enabled` false,
  `containerEngine.name` `moby`, `kubernetes.enabled` false. `create_` because Rancher rewrites the file on start.
- **R4** chezmoi manages neither `~/.docker/config.json` nor a docker context.
- **R5** Docs: ADR-0004, `docs/packages.md` glossary, `ReadMe.md` table via `docs-sync` (profile order includes
  `containers`).
- **R6** Migration in #46: before apply, save images and volumes and uninstall Docker Desktop; after apply, uninstall
  Scoop `docker`, `docker-compose`, `docker-buildx` and delete their copies in `~/.docker/cli-plugins`.

## Acceptance (real machine)

- [ ] After apply and a new login, no admin: Rancher runs in the background, no first-run dialog, moby, Kubernetes
  and updater off.
- [ ] `Get-Command docker -All` shows only Rancher's copy.
- [ ] `docker run --rm hello-world`, `docker compose up`, and a Testcontainers test with no `DOCKER_HOST` work.
- [ ] After `scoop update rancher-desktop` Rancher still starts at login (unverified: the login item may keep the old
  version path).
