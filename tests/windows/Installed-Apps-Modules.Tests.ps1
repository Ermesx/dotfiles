#Requires -Modules Pester
Describe "After installing dotfiles" {
    
    BeforeAll {
        $script:allApps = Get-WinGetPackage
        $script:allModules = Get-Module -ListAvailable
        $packagesPath = Join-Path $HOME ".local\share\chezmoi\.home\dot_config\winget-dsc\packages.dsc.winget"
        $resources = (Get-Content -Path $packagesPath | ConvertFrom-Yaml).properties.resources
        $script:wingets = $resources | Where-Object { $_.resource -eq 'Microsoft.WinGet.DSC/WinGetPackage' }
        $script:modules = $resources | Where-Object { $_.resource -eq 'PowerShellModule/PSModuleResource' }
    }
    
    Context "Apps" {
        It "should have installed <_>" -Foreach $script:wingets {
            $id = $_.settings.id
            $script:allApps | Where-Object { $_.Id -eq $id } | Should -Not -BeNullOrEmpty
        }
    }
    
    Context "Modules" {
        It "should have installed <_>" -Foreach $script:modules {
            $name = $_.settings.Module_Name
            $script:allModules | Where-Object { $_.Name -eq $name } | Should -Not -BeNullOrEmpty
        }
    }
}
