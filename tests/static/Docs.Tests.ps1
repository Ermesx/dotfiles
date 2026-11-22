#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '6.0.0' }

BeforeAll {
    Import-Module "$PSScriptRoot/StaticChecks.psm1" -Force
    $root = Resolve-Path "$PSScriptRoot/../.."
}

Describe 'docs' {

    It 'has no broken links in <_>' -ForEach 'AGENTS.md', 'docs/testing.md' {
        $path = Join-Path $root $_

        $path | Should -Exist
        Get-BrokenMarkdownLink -Path $path | Should -BeNullOrEmpty
    }

    It 'reports a broken link' {
        $file = Join-Path $TestDrive 'a.md'
        Set-Content -Path $file -Value '[x](missing.md) [y](https://example.com) [z](#anchor)'

        Get-BrokenMarkdownLink -Path $file | Should -Be 'missing.md'
    }
}
