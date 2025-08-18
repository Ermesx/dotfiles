#Requires -Modules Pester, Dotfiles-Toolkit

Describe "After installing dotfiles" {

    BeforeAll {
        Import-Module Dotfiles-Toolkit -Force
        $script:allApps = Get-WinGetPackage
        $script:allModules = Get-Module -ListAvailable
        $packagesPath = Join-Path $HOME ".local\share\chezmoi\.home\.chezmoidata\packages.yaml"
        $packages = (Get-Content -Path $packagesPath | ConvertFrom-Yaml).packages
    }
    Context "Apps" {
        It "should have installed <_>" -Foreach $packages.windows.wingets {
            $name = $_
            $script:allApps | Where-Object { $_.Id -like "*$name*" } | Should -Not -BeNullOrEmpty
        }
    }
    Context "Modules" {
        It "should have installed <_>" -Foreach $packages.windows.modules {
            $name = $_
            $script:allModules | Where-Object { $_.Name -eq $name } | Should -Not -BeNullOrEmpty
        }
    }
}
