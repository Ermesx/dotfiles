Describe "Dotfiles-Toolkit module installation" {
    It "should exist in the user's PowerShell Modules folder" -ForEach @(
        "$env:USERPROFILE\Documents\PowerShell\Modules\Dotfiles-Toolkit",
        "$env:USERPROFILE\Documents\WindowsPowerShell\Modules\Dotfiles-Toolkit"
    ) {

        Test-Path $_| Should -BeTrue
    }
}

Describe "Dotfiles-Toolkit functions availability" {
    It "should have function <_> available" -ForEach @(
        "Install-LocalModule",
        "Test-CommandAvailable",
        "Test-Installed",
        "Update-Env"
    ) {
        Get-Command $_ | should -Not -BeNullOrEmpty
    }    
}