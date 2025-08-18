#Requires -Modules Pester, Dotfiles-Toolkit

Describe 'Install-OrUpdateModule' {
    BeforeAll {
        Import-Module Dotfiles-Toolkit -Force
    }
    
    InModuleScope Dotfiles-Toolkit {
        BeforeAll {
            Mock Get-InstalledModule { @(@{ Name = 'TestModule'; Version = [version]'5.0.0' }, @{ Name = 'TestModule2'; Version = [version]'1.0.0' }) }
            Mock Install-Module { }
            Mock Find-Module { @{ Name = 'TestModule'; Version = [version]'5.1.0' } }
            Mock Update-Module { }
            Mock Write-Pretty { }
            Mock Write-Host { }
        }
        
        BeforeEach {
            $Global:ModulesCache = @()
            $Global:ModulesCacheTimer = (Get-Date).AddDays(-1)
            $Global:ModulesFindCache = @{}
            $Global:ModulesFindCacheTimer = (Get-Date).AddDays(-1)
        }
        
        It 'installs module if not present' {
            Mock Get-InstalledModule { @() }
            Install-OrUpdateModule -Name 'TestModule'
            Assert-MockCalled Install-Module -Exactly -Times 1
        }
        
        It 'updates module if newer version is available' {
            Mock Get-InstalledModule { @(@{ Name = 'TestModule'; Version = [version]'5.0.0' }, @{ Name = 'TestModule2'; Version = [version]'1.0.0' }) }
            Mock Find-Module { @{ Name = 'TestModule'; Version = [version]'5.1.0' } }
            Install-OrUpdateModule -Name 'TestModule'
            Assert-MockCalled Update-Module -Exactly -Times 1
        }

        It 'skips update if module is up-to-date' {
            Mock Get-InstalledModule { @(@{ Name = 'TestModule'; Version = [version]'5.1.0' }, @{ Name = 'TestModule2'; Version = [version]'1.0.0' }) }
            Mock Find-Module { @{ Name = 'TestModule'; Version = [version]'5.1.0' } }
            Install-OrUpdateModule -Name 'TestModule'
            Assert-MockCalled Update-Module -Exactly -Times 0
            Assert-MockCalled Install-Module -Exactly -Times 0
        }

        It 'forces reinstall if -Force is used' {
            Mock Get-InstalledModule { @(@{ Name = 'TestModule'; Version = [version]'5.1.0' }, @{ Name = 'TestModule2'; Version = [version]'1.0.0' }) }
            Install-OrUpdateModule -Name 'TestModule' -Force
            Assert-MockCalled Install-Module -Exactly -Times 1
        }

        It 'uses cache if ModulesCacheTimer is valid' {
            $Global:ModulesCache = @(@{ Name = 'TestModule'; Version = [version]'5.1.0' })
            $Global:ModulesCacheTimer = (Get-Date).AddDays(1)
            Mock Get-InstalledModule { throw 'Should not be called' }
            { Install-OrUpdateModule -Name 'TestModule' } | Should -Not -Throw
            Assert-MockCalled Get-InstalledModule -Times 0
        }

        It 'refreshes cache if ModulesCacheTimer is expired' {
            $Global:ModulesCache = @()
            $Global:ModulesCacheTimer = (Get-Date).AddDays(-1)
            Mock Get-InstalledModule { @(@{ Name = 'TestModule'; Version = [version]'5.1.0' }) }
            Install-OrUpdateModule -Name 'TestModule'
            Assert-MockCalled Get-InstalledModule -Times 1
        }

        It 'uses find cache if ModulesFindCacheTimer is valid' {
            $Global:ModulesCache = @(@{ Name = 'TestModule'; Version = [version]'5.0.0' })
            $Global:ModulesCacheTimer = (Get-Date).AddDays(1)
            $Global:ModulesFindCache = @{ 'TestModule' = @{ Name = 'TestModule'; Version = [version]'5.1.0' } }
            $Global:ModulesFindCacheTimer = (Get-Date).AddDays(1)
            Mock Find-Module { throw 'Should not be called' }
            { Install-OrUpdateModule -Name 'TestModule' } | Should -Not -Throw
            Assert-MockCalled Find-Module -Times 0
        }

        It 'refreshes find cache if ModulesFindCacheTimer is expired' {
            $Global:ModulesCache = @(@{ Name = 'TestModule'; Version = [version]'5.0.0' })
            $Global:ModulesCacheTimer = (Get-Date).AddDays(1)
            $Global:ModulesFindCache = @{}
            $Global:ModulesFindCacheTimer = (Get-Date).AddDays(-1)
            Mock Find-Module { @{ Name = 'TestModule'; Version = [version]'5.1.0' } }
            Install-OrUpdateModule -Name 'TestModule'
            Assert-MockCalled Find-Module -Times 1
        }
    }
}
