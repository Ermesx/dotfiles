#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '6.0.0' }

# The install scripts render from the packages view: they install the selection, and a script with nothing to do renders empty
BeforeAll {
    Import-Module "$PSScriptRoot/StaticChecks.psm1" -Force
    $root = Resolve-Path "$PSScriptRoot/../.."
    $scripts = Join-Path $root 'home/.chezmoiscripts/windows'

    function Get-RenderedScript([string]$Name, [hashtable]$Data = @{}, [switch]$NoCi) {
        $text = Get-Content -Raw (Join-Path $scripts $Name)
        $result = Invoke-ChezmoiCi -Source $root -Arguments @('execute-template') -InputText $text -Data $Data -NoCi:$NoCi
        $result.ExitCode | Should -Be 0 -Because ($result.Error -join "`n")
        $result.Output -join "`n"
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

    It 'deploys enable-wsl only where WSL is needed' {
        function Get-Managed([hashtable]$Data) {
            InModuleScope StaticChecks -Parameters @{ Source = "$root"; Data = $Data } { Get-ManagedPath -Source $Source -Data $Data }
        }

        Get-Managed @{ profiles = @('shell') } | Should -Not -Contain '.config/dotfiles/admin/enable-wsl.ps1'
        Get-Managed @{ profiles = @('containers') } | Should -Contain '.config/dotfiles/admin/enable-wsl.ps1'
    }
}
