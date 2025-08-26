#Requires -Modules Pester

Describe "After installing dotfiles" {

    BeforeAll {
        $script:allApps = Get-WinGetPackage
        $script:allModules = Get-Module -ListAvailable
        $packagesPath = Join-Path $HOME ".local\share\chezmoi\.home\dot_config\winget-dsc\packages.dsc.winget"
        $resources = (Get-Content -Path $packagesPath | ConvertFrom-Yaml).properties.resources
        $wingets = $resources | Where-Object { $_.resource -eq 'Microsoft.WinGet.DSC/WinGetPackage' }
        $modules = $resources | Where-Object { $_.resource -eq 'PowerShellModule/PSModuleResource' }
    }
    
    Context "Apps" {
        It "should have installed <_>" -Foreach $wingets {
            $id = $_
            $script:allApps | Where-Object { $_.Id -like "*$id*" } | Should -Not -BeNullOrEmpty
        }
    }
    
    Context "Modules" {
        It "should have installed <_>" -Foreach $modules {
            $name = $_
            $script:allModules | Where-Object { $_.Name -eq $name } | Should -Not -BeNullOrEmpty
        }
    }
}
