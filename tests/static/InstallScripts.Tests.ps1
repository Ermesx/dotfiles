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
            $out | Should -Match "(?m)^\s*'$([regex]::Escape($app))'\s*$"
        }
        $out | Should -Not -Match "'dotnet-sdk'"
        $out | Should -Not -Match "'extras/rider'"
    }

    It 'installs only picked apps' {
        $out = Get-RenderedScript 'run_onchange_before_01-scoop.ps1.tmpl' -Data @{ profiles = @('apps'); picks = @{ apps = @('postman') } }

        $out | Should -Match "(?m)^\s*'extras/postman'\s*$"
        $out | Should -Not -Match "'extras/rider'"
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

Describe 'install scripts use StepProgress' {

    BeforeAll {
        $importLine = "Import-Module (Join-Path `$env:CHEZMOI_SOURCE_DIR 'readonly_Documents/PowerShell/Modules/StepProgress/StepProgress.psd1')"
    }

    It 'imports the module, calls Invoke-ProgressSteps and exits on failure in <_>' -ForEach @(
        'run_onchange_before_01-scoop.ps1.tmpl', 'run_onchange_before_02-modules.ps1.tmpl',
        'run_onchange_before_03-dotnet-tools.ps1.tmpl', 'run_once_after_yazi-plugins.ps1.tmpl') {
        $out = Get-RenderedScript $_

        $out | Should -Match ([regex]::Escape($importLine))
        $out | Should -Match 'Invoke-ProgressSteps'
        $out.TrimEnd() | Should -Match '(?m)^exit \[int\]\(\$result\.Failed\.Count -gt 0\)$'
    }

    It 'bakes no absolute path into <_>' -ForEach @(
        'run_onchange_before_01-scoop.ps1.tmpl', 'run_onchange_before_02-modules.ps1.tmpl',
        'run_onchange_before_03-dotnet-tools.ps1.tmpl', 'run_once_after_yazi-plugins.ps1.tmpl') {
        # A drive letter not preceded by a letter, so that https:// is not one
        Get-RenderedScript $_ | Should -Not -Match '(?<![A-Za-z])[A-Za-z]:[\\/]'
    }

    It 'checks scoop presence by the app name without its bucket' {
        Get-RenderedScript 'run_onchange_before_01-scoop.ps1.tmpl' | Should -Match ([regex]::Escape("(`$app -split '/')[-1] -in `$installed"))
    }

    It 'keeps templates out of the module folder' {
        Get-ChildItem "$root/home/readonly_Documents/PowerShell/Modules/StepProgress" -Recurse -Filter *.tmpl | Should -BeNullOrEmpty
    }

    It 'loads the module with the import line of the scripts' {
        $saved = $env:CHEZMOI_SOURCE_DIR
        try {
            $env:CHEZMOI_SOURCE_DIR = "$root/home"
            $module = Invoke-Expression ($importLine -replace '^Import-Module \(', 'Import-Module -Force -PassThru (')
            $module.Name | Should -Be 'StepProgress'
        }
        finally {
            $env:CHEZMOI_SOURCE_DIR = $saved
            Remove-Module StepProgress -Force -ErrorAction SilentlyContinue
        }
    }
}