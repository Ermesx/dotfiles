#Requires -Modules Pester
Describe "After installing dotfiles" {

    BeforeDiscovery {
        $configPath = Join-Path $HOME '.config\config.dsc.yaml'
        $resources = (Get-Content -Path $configPath | ConvertFrom-Yaml).resources
        $script:packages = $resources | Where-Object { $_.type -eq 'Microsoft.WinGet/Package' }
        $script:modules = $resources | Where-Object { $_.type -eq 'AnyPackageDsc/Package' }
    }

    BeforeAll {
        $script:allApps = Get-WinGetPackage
        $script:allModules = Get-Module -ListAvailable
    }

    Context "Apps" {
        It "should have installed <_>" -Foreach $script:packages.properties.id {
            $id = $_
            $script:allApps | Where-Object { $_.Id -eq $id } | Should -Not -BeNullOrEmpty
        }
    }

    Context "Modules" {
        It "should have installed <_>" -Foreach $script:modules.properties.Name {
            $name = $_
            $script:allModules | Where-Object { $_.Name -eq $name } | Should -Not -BeNullOrEmpty
        }
    }
}
