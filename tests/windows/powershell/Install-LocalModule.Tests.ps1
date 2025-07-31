#Requires -Modules Pester, Dotfiles-Toolkit

Describe 'Install-LocalModule' {
    BeforeAll {
        Import-Module Dotfiles-Toolkit -Force
    }
    
    InModuleScope Dotfiles-Toolkit {
        BeforeAll {
            Mock Import-PowerShellDataFile { @{ ModuleVersion = '1.0.0' } }
            Mock Write-Pretty { }
            Mock Write-Host { }
            Mock Test-Path { $false }
            Mock New-Item { }
            Mock Add-Content { }
            Mock Get-Content { 'content' }
            Mock Copy-Item { }
            Mock Remove-Item { }
        }
        
        It 'installs module if not present' {
            Mock Get-Module { @() }
            Install-LocalModule -SourceModulePath 'C:\TestModule'
            Assert-MockCalled Copy-Item  -Times 1
        }
        
        It 'skips install if same version exists and not forced' {
            Mock Get-Module { @{ Name = 'TestModule'; Version = '1.0.0' } }
            Mock Import-PowerShellDataFile { @{ ModuleVersion = '1.0.0' } }
            Install-LocalModule -SourceModulePath 'C:\TestModule'
            Assert-MockCalled Copy-Item -Exactly -Times 0
        }
        
        It 'forces install if -Force is used' {
            Mock Get-Module { @{ Name = 'TestModule'; Version = '1.0.0' } }
            Mock Import-PowerShellDataFile { @{ ModuleVersion = '1.0.0' } }
            Install-LocalModule -SourceModulePath 'C:\TestModule' -Force
            Assert-MockCalled Copy-Item -Times 1
        }
        
        It 'updates if higher version exists' {
            Mock Get-Module { @{ Name = 'TestModule'; Version = '1.0.0' } }
            Mock Import-PowerShellDataFile { @{ ModuleVersion = '2.0.0' } }
            Install-LocalModule -SourceModulePath 'C:\TestModule'
            Assert-MockCalled Copy-Item -Times 1
        }
    }
}
