# Load modules
Import-Module Dotfiles-Toolkit
Import-Module Microsoft.WinGet.Client
Import-Module Pester

# Initialize oh-my-posh
oh-my-posh init pwsh --config "$env:POSH_THEMES_PATH/jandedobbeleer.omp.json" | Invoke-Expression

