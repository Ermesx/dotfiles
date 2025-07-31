#Requires -Modules Pester, Dotfiles-Toolkit

Describe "After installing dotfiles" {

    BeforeAll {
        Import-Module Dotfiles-Toolkit -Force
        $script:allApps = Get-WinGetPackage
        $script:allModules = Get-Module -ListAvailable
    }
    Context "Apps" {
        It "should have installed <_>" -Foreach @(
            "PowerShell",
            "Oh My Posh",
            "Windows Terminal",
            "Git",
            "GitQL",
            "lazygit",
            "onefetch",
            "Git Credential Manager (User)",
            "Docker Desktop",
            "zoxide",
            "fzf",
            "fd",
            "eza",
            "bat",
            "RipGrep MSVC",
            "file"
        ) {
            $name = $_
            $script:allApps | Where-Object { $_.Name -like "*$name*" } | Should -Not -BeNullOrEmpty
        }
    }
    Context "Modules" {
        It "should have installed <_>" -Foreach @(
            "Microsoft.WinGet.Client",
            "Pester",
            "PSFzf",
            "posh-git",
            "DockerCompletion",
            "Terminal-Icons",
            "PSScriptAnalyzer",
            "PSMustache"
        ) {
            $name = $_
            $script:allModules | Where-Object { $_.Name -eq $name } | Should -Not -BeNullOrEmpty
        }
    }
}
