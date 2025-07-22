# Requires -Module Pester
# Requires -Module Dotfiles-Toolkit

Describe 'Update-Env' {
    
    BeforeAll {
        Import-Module Dotfiles-Toolkit -Force
    }
    
    InModuleScope Dotfiles-Toolkit {
        BeforeAll {

            Mock Test-Path { return $true }

            Mock Get-EnvVar {
                param ($Name, $Scope)
                switch ($Scope)
                {
                    'User'    {
                        return 'C:\User1;C:\User2'
                    }
                    'Machine' {
                        return 'C:\Machine1'
                    }
                }
            }

            Mock Set-EnvVar { }
            
            Mock Write-Host { }
        }

        Context 'Valid path added to user PATH' {
            It 'calls Set-EnvVar with the new valid path and updates $env:Path' {
                Update-Env -AdditionalPath "D:\Valid"

                Assert-MockCalled Set-EnvVar -Exactly -Times 1 -ParameterFilter {
                    $Name -eq 'Path' -and
                            $Scope -eq [EnvironmentVariableTarget]::User -and
                            $Value -eq 'C:\User1;C:\User2;D:\Valid'
                }

                $env:Path | Should -Be 'C:\Machine1;C:\User1;C:\User2;D:\Valid'
            }
        }

        Context 'Duplicate path not added' {
            It 'does not call Set-EnvVar if path already exists in user PATH' {
                Update-Env -AdditionalPath "C:\User1"

                Assert-MockCalled Set-EnvVar -Times 0
                $env:Path | Should -Be 'C:\Machine1;C:\User1;C:\User2'
            }
        }

        Context 'Invalid path ignored' {
            It 'skips path that does not exist' {
                Mock Test-Path { return $false }

                Update-Env -AdditionalPath "Z:\NonExistent"

                Assert-MockCalled Set-EnvVar -Times 0
                $env:Path | Should -Be 'C:\Machine1;C:\User1;C:\User2'
            }
        }

        Context 'Empty or whitespace path' {
            It 'does not update anything' {
                Update-Env -AdditionalPath ""
                Update-Env -AdditionalPath "   "

                Assert-MockCalled Set-EnvVar -Times 0
            }
        }

        Context 'Mixed valid, invalid and duplicate paths' {
            It 'adds only valid and new paths' {
                Mock Test-Path {
                    param($path)
                    return $path -ne "Z:\Broken"
                }

                Update-Env -AdditionalPath "C:\User2;D:\Valid;Z:\Broken"

                Assert-MockCalled Set-EnvVar -Exactly -Times 1 -ParameterFilter {
                    $Value -eq 'C:\User1;C:\User2;D:\Valid'
                }

                $env:Path | Should -Be 'C:\Machine1;C:\User1;C:\User2;D:\Valid'
            }
        }

        Context 'Multiple valid new paths' {
            It 'appends all new valid paths in order' {
                Update-Env -AdditionalPath "D:\One;E:\Two"

                Assert-MockCalled Set-EnvVar -Exactly -Times 1 -ParameterFilter {
                    $Value -eq 'C:\User1;C:\User2;D:\One;E:\Two'
                }

                $env:Path | Should -Be 'C:\Machine1;C:\User1;C:\User2;D:\One;E:\Two'
            }
        }
    }
}
