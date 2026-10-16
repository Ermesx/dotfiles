# Packages

- `home/.chezmoidata/packages.yaml` is the source of truth for what gets installed: winget IDs, PowerShell modules,
  dotnet tools, yazi plugins, WSL distro, Linux packages. Templates, the DSC document, profile `Import-Module`
  lines, and tests all derive from it — never add a package anywhere else. Keep entries under the existing
  category comments.
- The package table in `ReadMe.md` is a manual mirror of that file. Update it in the same change.
- Every id in `packages.yaml` sits under a group comment (`# shell`, `# git`, …) taken from the category glossary
  below. Add a new category here first, then use it.
- Winget entries must be exact winget package IDs (`Publisher.Name`). Verify with `winget show --id <Id> --exact`.
- Every module in `packages.windows.modules` is imported in every PowerShell session. Add only modules that are
  cheap to import.
- A change to `packages.yaml` reruns the DSC apply script on the next apply (see `docs/chezmoi.md`). Check drift
  with the DSC command in `AGENTS.md`.

## Categories

The only allowed values for the group comments in `packages.yaml` and for the *Category* column of the README
package table.

| Category | What belongs there |
|---|---|
| `shell` | Shells, terminals, prompt, navigation helpers, file managers and their plugins, general shell modules |
| `fzf` | Fuzzy finder and the search tools built around it (`fd`, `ripgrep`, `eza`, `bat`) and their modules |
| `git` | Git, Git UIs and diff/pager tools, repo inspection, Git modules |
| `dotnet` | .NET SDKs and .NET global tools |
| `node` | Node.js runtime and tooling |
| `containers` | Docker, Vagrant and other container or VM tooling, and their modules |
| `chezmoi` | The dotfiles manager itself |
| `editors` | Code editors and IDEs |
| `browsers` | Web browsers |
| `other` | Anything that fits no category above (utilities, PowerShell helper modules, the WSL distro) |
