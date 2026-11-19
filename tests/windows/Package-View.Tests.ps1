#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '6.0.0' }

Describe 'Package view (packages.tmpl)' {

    BeforeAll {
        $src = Join-Path $PSScriptRoot '../..'
        $sourceArgs = if (Test-Path (Join-Path $src '.chezmoiroot')) { @('--source', (Resolve-Path $src)) } else { @() }
        $json = '{{ includeTemplate "packages.tmpl" . }}' | chezmoi @sourceArgs execute-template
        $script:view = $json | ConvertFrom-Json
    }

    It 'has exactly the expected methods' {
        ($view.PSObject.Properties.Name | Sort-Object) | Should -Be @('dotnet_tools', 'modules', 'scoop', 'wsl', 'yazi_plugins')
    }

    It 'merges 39 scoop apps' {
        $view.scoop.Count | Should -Be 39
    }

    It 'keeps bucket-prefixed and plain scoop apps' {
        $view.scoop | Should -Contain 'extras/windows-terminal'
        $view.scoop | Should -Contain 'nerd-fonts/Hasklig-NF'
        $view.scoop | Should -Contain 'claude-code'
    }

    It 'lists the PowerShell modules' {
        ($view.modules | Sort-Object) | Should -Be @('DockerCompletion', 'Pester', 'posh-git', 'powershell-yaml', 'PSfzf', 'Terminal-Icons')
    }

    It 'lists 12 dotnet tools' {
        $view.dotnet_tools.Count | Should -Be 12
    }

    It 'lists the WSL distro' {
        $view.wsl | Should -Be 'Ubuntu-24.04'
    }

    It 'lists the yazi plugin' {
        $view.yazi_plugins | Should -Be 'yazi-rs/plugins:full-border'
    }
}
