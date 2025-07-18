Describe "After installing dotfiles " {
    Context "Apps" {
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

    Context "Modules" {
        It "should have installed <_>" -Foreach @(
            "Microsoft.WinGet.Client",
            "Pester",
            "PSFzf",
            "posh-git",
            "DockerCompletion"
        ) {
            Get-Module -Name $_ -ListAvailable | Should -Not -BeNullOrEmpty
        }
    }
}