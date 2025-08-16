#Requires -Modules Pester, Dotfiles-Toolkit

Describe "Dotfiles-Toolkit installation" {

    BeforeAll {
        Import-Module Dotfiles-Toolkit -Force
    }

    Context "module" {
        It "should be installed" {
            $module = Get-Module -Name Dotfiles-Toolkit -ListAvailable
            $module | Should -Not -BeNullOrEmpty
        }

        It "should exist in the user's PowerShell Modules folder" {
            $path = "~\Documents\PowerShell\Modules\Dotfiles-Toolkit"
            Test-Path $path | Should -BeTrue
        }

        It "should have exported function <_> available" -ForEach @(
            "Add-ToProfile",
            "Clear-Profile",
            "Install-LocalModule",
            "Install-OrUpdateApp",
            "Install-OrUpdateModule",
            "Update-Env",
            "Update-ScriptBlock",
            "Write-Pretty",
            "Update-KeyBinding"
        ) {
            Get-Command $_ | should -Not -BeNullOrEmpty
        }
    }
}