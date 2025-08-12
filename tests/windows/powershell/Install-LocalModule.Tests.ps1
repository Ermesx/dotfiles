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
            Mock Write-Yellow { }
            Mock Write-Cyan { }
            Mock Write-Green { }
            Mock Test-Path { $false }
            Mock New-Item { }
            Mock Add-Content { }
            Mock Get-Content { 'content' }
            Mock Copy-Item { }
            Mock Remove-Item { }
            Mock Split-Path { 'TestModule' }
            Mock Join-Path { 
                param($Path, $ChildPath)
                if ($Path -like '*Modules') { "$Path\$ChildPath" }
                else { "$Path\$ChildPath" }
            }
        }
        
        It 'installs module if not present' {
            Mock Get-Module { @() }
            Install-LocalModule -SourceModulePath 'C:\TestModule'
            Assert-MockCalled Copy-Item -Times 1
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
        
        It 'uses PowerShell 7 path when Version is 7' {
            Mock Get-Module { @() }
            Mock Join-Path { 
                param($Path, $ChildPath)
                if ($Path -eq '~\Documents\PowerShell\Modules') { 
                    return "PowerShell7Path\$ChildPath" 
                }
                return "$Path\$ChildPath"
            }
            
            Install-LocalModule -SourceModulePath 'C:\TestModule' -Version 7
            Assert-MockCalled Join-Path -ParameterFilter { $Path -eq '~\Documents\PowerShell\Modules' }
        }
        
        It 'uses Windows PowerShell path when Version is 5' {
            Mock Get-Module { @() }
            Mock Join-Path { 
                param($Path, $ChildPath)
                if ($Path -eq '~\Documents\WindowsPowerShell\Modules') { 
                    return "WindowsPowerShellPath\$ChildPath" 
                }
                return "$Path\$ChildPath"
            }
            
            Install-LocalModule -SourceModulePath 'C:\TestModule' -Version 5
            Assert-MockCalled Join-Path -ParameterFilter { $Path -eq '~\Documents\WindowsPowerShell\Modules' }
        }
    }
}
