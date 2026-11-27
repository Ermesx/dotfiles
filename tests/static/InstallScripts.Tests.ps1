#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '6.0.0' }

# The install scripts render from the packages view: they install the selection, and a script with nothing to do renders empty
BeforeAll {
    Import-Module "$PSScriptRoot/StaticChecks.psm1" -Force
    $root = Resolve-Path "$PSScriptRoot/../.."

    function Get-RenderedScript([string]$Name, [hashtable]$Data = @{}, [switch]$NoCi) {
        # Joined: the assertions match multi-line text
        (Get-RenderedTemplate -Source $root -Path "home/.chezmoiscripts/windows/$Name" -Data $Data -NoCi:$NoCi) -join "`n"
    }
}

Describe 'install scripts follow the selection' {

    It 'installs base and shell only' {
        $out = Get-RenderedScript 'run_onchange_before_01-scoop.ps1.tmpl' -Data @{ profiles = @('shell') }

        foreach ($app in 'extras/vscode', 'delta', 'less', 'jq', 'starship') {
            $out | Should -Match "(?m)^scoop install $([regex]::Escape($app))\s*$"
        }
        $out | Should -Not -Match 'scoop install dotnet-sdk'
        $out | Should -Not -Match 'scoop install extras/rider'
    }

    It 'installs only picked apps' {
        $out = Get-RenderedScript 'run_onchange_before_01-scoop.ps1.tmpl' -Data @{ profiles = @('apps'); picks = @{ apps = @('postman') } }

        $out | Should -Match 'scoop install extras/postman'
        $out | Should -Not -Match 'scoop install extras/rider'
    }

    It 'ignores CI for the selection' {
        $data = @{ profiles = @('apps'); picks = @{ apps = @('postman') } }

        Get-RenderedScript 'run_onchange_before_01-scoop.ps1.tmpl' -Data $data |
            Should -Be (Get-RenderedScript 'run_onchange_before_01-scoop.ps1.tmpl' -Data $data -NoCi)
    }

    It 'renders no WSL script without a distro' {
        (Get-RenderedScript 'run_once_before_install-wsl.ps1.tmpl' -Data @{ profiles = @('shell') }) | Should -Match '^\s*$'
        Get-RenderedScript 'run_once_before_install-wsl.ps1.tmpl' | Should -Match 'Ubuntu-24\.04'
    }

    It 'renders no yazi script without shell' {
        (Get-RenderedScript 'run_once_after_yazi-plugins.ps1.tmpl' -Data @{ profiles = @('sdk') }) | Should -Match '^\s*$'
        Get-RenderedScript 'run_once_after_yazi-plugins.ps1.tmpl' -Data @{ profiles = @('shell') } | Should -Match 'full-border'
    }

    It 'installs modules and .NET tools of the selection' {
        $data = @{ profiles = @('shell') }

        $modules = Get-RenderedScript 'run_onchange_before_02-modules.ps1.tmpl' -Data $data
        $modules | Should -Match 'PSfzf'
        $modules | Should -Not -Match 'Pester'

        Get-RenderedScript 'run_onchange_before_03-dotnet-tools.ps1.tmpl' -Data $data | Should -Not -Match 'dotnet tool install'
    }

    It 'passes --no-tty to chezmoi init only when CI is true' {
        # A runner has no TTY, so chezmoi reads prompt answers from stdin there; the work email reaches CI
        # through DOTFILES_GIT_WORK_EMAIL because of this
        $text = Get-Content -Raw (Join-Path $root 'install.ps1')

        $text | Should -Match "\`$initArgs = @\(if \(\`$env:CI -eq 'true'\) \{ '--no-tty' \}\)"
        $text | Should -Match 'chezmoi init --apply \$GITHUB_USERNAME @initArgs'
    }

    It 'deploys enable-wsl only where WSL is needed' {
        Get-ManagedPath -Source $root -Data @{ profiles = @('shell') } | Should -Not -Contain '.config/dotfiles/admin/enable-wsl.ps1'
        Get-ManagedPath -Source $root -Data @{ profiles = @('containers') } | Should -Contain '.config/dotfiles/admin/enable-wsl.ps1'
    }
}
