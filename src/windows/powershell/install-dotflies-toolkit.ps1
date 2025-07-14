# Install or upgrade the Dotfiles-Toolkit module

. "$PSScriptRoot\dotfiles-toolkit\functions\install-LocalModule.ps1"
Install-LocalModule -SourceModulePath "$PSScriptRoot\Dotfiles-Toolkit" -Force
Import-Module Dotfiles-Toolkit -Force