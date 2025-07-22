# Requires -Module Pester
# Requires -Module Dotfiles-Toolkit

Describe "After installing dotfiles" {

    BeforeAll {
        Import-Module Dotfiles-Toolkit -Force
    }
    
    Context " Apps" {
        It "should have installed <_>" -Foreach @(
            "Oh-My-Posh",
            "Windows Terminal",
            "Git",
            "Docker",
            "Zoxide",
            "Fzf"
        ) {
            Get-WinGetPackage -Name $_ | Should -Not -BeNullOrEmpty
        }
    }

    Context " Modules" {
        It " should have installed <_>" -Foreach @(
            "Microsoft.WinGet.Client",
            "Pester",
            "PSFzf",
            "posh-git",
            "DockerCompletion",
            "Terminal-Icons"
        ) {
            Get-Module -Name $_ -ListAvailable | Should -Not -BeNullOrEmpty
        }
    }
}
