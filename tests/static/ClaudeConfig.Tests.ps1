#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '6.0.0' }

# install-profiles R23-R24: Claude configuration and lazygit's AI commit command only with claude-code
BeforeAll {
    Import-Module "$PSScriptRoot/StaticChecks.psm1" -Force
    $root = Resolve-Path "$PSScriptRoot/../.."
    $lazygitTemplate = 'home/readonly_AppData/Local/lazygit/config.yml.tmpl'

    function Get-Managed([hashtable]$Data) {
        InModuleScope StaticChecks -Parameters @{ Source = "$root"; Data = $Data } {
            if ($Data) { Get-ManagedPath -Source $Source -Data $Data } else { Get-ManagedPath -Source $Source }
        }
    }

    function Get-Rendered([string]$RelativePath, [hashtable]$Data) {
        InModuleScope StaticChecks -Parameters @{
            Source = "$root"; Text = (Get-Content -Raw (Join-Path $root $RelativePath)); Data = $Data
        } {
            $arguments = @{ Source = $Source; Arguments = @('execute-template'); InputText = $Text }
            if ($Data) { $arguments.Data = $Data }
            # Output arrives as lines (the last one empty after the final newline); joined, it compares exactly
            (Invoke-ChezmoiCi @arguments).Output -join "`n"
        }
    }
}

Describe 'Claude configuration' {

    It 'deploys no Claude config without claude-code' {
        $managed = Get-Managed @{ profiles = @('shell') }

        $managed | Where-Object { $_ -like '.claude*' } | Should -BeNullOrEmpty
        $managed | Should -Not -Contain 'AppData/Local/lazygit/ai-commit.ps1'
    }

    It 'deploys Claude config with claude-code' {
        $managed = Get-Managed @{ profiles = @('ai'); picks = @{ ai = @('claude-code') } }

        $managed | Where-Object { $_ -like '.claude*' } | Should -Not -BeNullOrEmpty
        $managed | Should -Contain 'AppData/Local/lazygit/ai-commit.ps1'
    }
}

Describe 'lazygit config' {

    It 'renders unchanged with claude-code' {
        $fixture = Get-Content -Raw (Join-Path $PSScriptRoot 'fixtures/lazygit-config.yml')

        (Get-Rendered $lazygitTemplate) -ceq $fixture | Should -BeTrue
    }

    It 'renders no AI command without claude-code' {
        $rendered = Get-Rendered $lazygitTemplate @{ profiles = @('shell') }

        $rendered | Should -Not -Match '<c-a>'
        $rendered | Should -Not -Match 'customCommands:'
        $rendered | Should -Match "editPreset: 'vscode'"
    }
}
