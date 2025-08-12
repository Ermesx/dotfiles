#Requires -Modules Pester, Dotfiles-Toolkit

Describe 'Install-OrUpdateApp' {
    BeforeAll {
        Import-Module Dotfiles-Toolkit -Force
    }

    InModuleScope Dotfiles-Toolkit {
        BeforeAll {
            Mock Get-WinGetPackage { @{ Id = 'Test.App'; InstalledVersion = '1.0.0'; IsUpdateAvailable = $false; AvailableVersions = @('1.0.0') } }
            Mock Install-WinGetPackage { }
            Mock Update-WinGetPackage { }
            Mock Write-Pretty { }
            Mock Write-Host { }
            Mock Update-Env { }
            Mock Get-Command { $null }
        }
        
        BeforeEach {
            $Global:AppsCache = @()
            $Global:AppsCacheTimer = (Get-Date).AddDays(-1) 
        }
        
        It 'installs app if not present' {
            Mock Get-WinGetPackage { @() }
            Install-OrUpdateApp -AppId 'Test.App'
            Assert-MockCalled Install-WinGetPackage -Exactly -Times 1
        }
        
        It 'updates app if update is available' {
            $Global:AppsCache = @(@{ Id = 'Test.App'; InstalledVersion = '1.0.0'; IsUpdateAvailable = $true; AvailableVersions = @('2.0.0') })
            $Global:AppsCacheTimer = (Get-Date).AddDays(1)
            Mock Get-WinGetPackage { @{ Id = 'Test.App'; InstalledVersion = '2.0.0'; IsUpdateAvailable = $false; } }
            Install-OrUpdateApp -AppId 'Test.App'
            Assert-MockCalled Update-WinGetPackage -Exactly -Times 1
        }
        
        It 'skips update if app is up-to-date' {
            Install-OrUpdateApp -AppId 'Test.App'
            Assert-MockCalled Update-WinGetPackage -Exactly -Times 0
            Assert-MockCalled Install-WinGetPackage -Exactly -Times 0
        }
        
        It 'forces reinstall if -Force is used' {
            $Global:AppsCache = @(@{ Id = 'Test.App'; InstalledVersion = '1.0.0'; IsUpdateAvailable = $true; AvailableVersions = @('2.0.0') })
            $Global:AppsCacheTimer = (Get-Date).AddDays(1)
            Mock Get-WinGetPackage { @{ Id = 'Test.App'; InstalledVersion = '2.0.0'; IsUpdateAvailable = $false; } }
            Install-OrUpdateApp -AppId 'Test.App' -Force
            Assert-MockCalled Install-WinGetPackage -Exactly -Times 1
        }
        
        It 'calls Update-Env if Command provided and missing from PATH' {
            Mock Get-Command { $null }
            Install-OrUpdateApp -AppId 'Test.App' -Command 'testcmd' -AdditionalEnvPath 'C:\TestPath'
            Assert-MockCalled Update-Env -Exactly -Times 1 -ParameterFilter { $AdditionalPath -eq 'C:\TestPath' }
        }
        
        It 'uses cache if AppsCacheTimer is valid' {
            $Global:AppsCache = @(@{ Id = 'Test.App'; InstalledVersion = '1.0.0'; IsUpdateAvailable = $false; AvailableVersions = @('1.0.0') })
            $Global:AppsCacheTimer = (Get-Date).AddDays(1)
            Mock Get-WinGetPackage { throw 'Should not be called' }
            { Install-OrUpdateApp -AppId 'Test.App' } | Should -Not -Throw
            Assert-MockCalled Get-WinGetPackage -Times 0
        }
        
        It 'refreshes cache if AppsCacheTimer is expired' {
            $Global:AppsCache = @()
            $Global:AppsCacheTimer = (Get-Date).AddDays(-1)
            Mock Get-WinGetPackage { @(@{ Id = 'Test.App'; InstalledVersion = '1.0.0'; IsUpdateAvailable = $false; AvailableVersions = @('1.0.0') }) }
            Install-OrUpdateApp -AppId 'Test.App'
            Assert-MockCalled Get-WinGetPackage -Times 1
        }

        It 'skips Update-Env if command exists in PATH' {
            Mock Get-Command { [pscustomobject]@{ Name = 'testcmd' } }
            Install-OrUpdateApp -AppId 'Test.App' -Command 'testcmd' -AdditionalEnvPath 'C:\TestPath'
            Assert-MockCalled Update-Env -Times 0
        }
    }
}
