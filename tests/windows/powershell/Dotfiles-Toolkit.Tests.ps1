Describe "Dotfiles-Toolkit module installation" {
    It "should exist in the user's PowerShell Modules folder" {
        $modulePath = Join-Path -Path "$env:USERPROFILE\Documents\PowerShell\Modules" -ChildPath "Dotfiles-Toolkit"
        Test-Path $modulePath | Should -BeTrue
    }
}