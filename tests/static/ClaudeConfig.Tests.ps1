#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '6.0.0' }

# Claude configuration and lazygit's AI commit command only with claude-code
BeforeAll {
    Import-Module "$PSScriptRoot/StaticChecks.psm1" -Force
    $root = Resolve-Path "$PSScriptRoot/../.."
    $lazygitTemplate = 'home/readonly_AppData/Local/lazygit/config.yml.tmpl'
}

Describe 'Claude configuration' {

    It 'deploys no Claude config without claude-code' {
        $managed = Get-ManagedPath -Source $root -Data @{ profiles = @('shell') }

        $managed | Where-Object { $_ -like '.claude*' } | Should -BeNullOrEmpty
        $managed | Should -Not -Contain 'AppData/Local/lazygit/ai-commit.ps1'
    }

    It 'deploys Claude config with claude-code' {
        $managed = Get-ManagedPath -Source $root -Data @{ profiles = @('ai'); picks = @{ ai = @('claude-code') } }

        $managed | Where-Object { $_ -like '.claude*' } | Should -Not -BeNullOrEmpty
        $managed | Should -Contain 'AppData/Local/lazygit/ai-commit.ps1'
    }
}

Describe 'lazygit config' {

    It 'renders unchanged with claude-code' {
        $fixture = Get-Content -Raw (Join-Path $PSScriptRoot 'fixtures/lazygit-config.yml')

        ((Get-RenderedTemplate -Source $root -Path $lazygitTemplate) -join "`n") -ceq $fixture | Should -BeTrue
    }

    It 'renders no AI command without claude-code' {
        $rendered = (Get-RenderedTemplate -Source $root -Path $lazygitTemplate -Data @{ profiles = @('shell') }) -join "`n"

        $rendered | Should -Not -Match '<c-a>'
        $rendered | Should -Not -Match 'customCommands:'
        $rendered | Should -Match "editPreset: 'vscode'"
    }
}
