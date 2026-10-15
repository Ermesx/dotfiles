# Packages

- `home/.chezmoidata/packages.yaml` is the source of truth for what gets installed: winget IDs, PowerShell modules,
  dotnet tools, yazi plugins, WSL distro, Linux packages. Templates, the DSC document, profile `Import-Module`
  lines, and tests all derive from it — never add a package anywhere else. Keep entries under the existing
  category comments.
- The package table in `ReadMe.md` is a manual mirror of that file. Update it in the same change.
- Winget entries must be exact winget package IDs (`Publisher.Name`). Verify with `winget show --id <Id> --exact`.
- Every module in `packages.windows.modules` is imported in every PowerShell session. Add only modules that are
  cheap to import.
- A change to `packages.yaml` reruns the DSC apply script on the next apply (see `docs/chezmoi.md`). Check drift
  with the DSC command in `AGENTS.md`.
