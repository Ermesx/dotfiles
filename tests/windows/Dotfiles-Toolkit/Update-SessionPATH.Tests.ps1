#Requires -Modules Pester, Dotfiles-Toolkit

Describe 'Update-SessionPATH' {
    
    BeforeAll {
        Import-Module Dotfiles-Toolkit -Force
    }    
    
    InModuleScope Dotfiles-Toolkit {
        BeforeAll {
            
            $script:OriginalPath = $env:Path

            Mock Test-Path { $true }
            Mock Write-Host { }
            Mock Write-Verbose { }
            Mock Set-EnvVar { }
            Mock Get-EnvVar {
                param ($Name, $Scope)
                switch ($Scope) {
                    'User'    { return 'C:\User1;C:\User2' }
                    'Machine' { return 'C:\Machine1' }
                }
            }
        }

        AfterAll {
            $env:Path = $script:OriginalPath
        }

        Context 'Valid path added to user PATH' {
            It 'calls Set-EnvVar with unique paths including new valid path' {
                Update-SessionPATH -AdditionalPath "D:\Valid"

                Assert-MockCalled Set-EnvVar -Exactly -Times 1 -ParameterFilter {
                    $Name -eq 'Path' -and
                    $Scope -eq [EnvironmentVariableTarget]::User -and
                    $Value -match 'D:\\Valid'
                }

                $env:Path | Should -Be 'C:\Machine1;C:\User1;C:\User2;D:\Valid'
            }
        }

        Context 'Duplicate path handling' {
            It 'filters out duplicate paths when adding to user PATH' {
                Update-SessionPATH -AdditionalPath "C:\User1;D:\Valid"

                Assert-MockCalled Set-EnvVar -Exactly -Times 1 -ParameterFilter {
                    $Name -eq 'Path' -and
                    $Scope -eq [EnvironmentVariableTarget]::User -and
                    $Value -eq 'C:\User1;C:\User2;D:\Valid'
                }

                $env:Path | Should -Be 'C:\Machine1;C:\User1;C:\User2;D:\Valid'
            }
        }

        Context 'Invalid path filtered out' {
            It 'skips paths that do not exist' {
                Mock Test-Path { 
                    param($Path)
                    return $Path -ne "Z:\NonExistent"
                }

                Update-SessionPATH -AdditionalPath "Z:\NonExistent;D:\Valid"

                Assert-MockCalled Set-EnvVar -Exactly -Times 1 -ParameterFilter {
                    $Name -eq 'Path' -and
                    $Scope -eq [EnvironmentVariableTarget]::User -and
                    $Value -eq 'C:\User1;C:\User2;D:\Valid'
                }

                $env:Path | Should -Be 'C:\Machine1;C:\User1;C:\User2;D:\Valid'
            }
        }

        Context 'Empty or whitespace path' {
            It 'does not update PATH when AdditionalPath is empty' {
                Update-SessionPATH -AdditionalPath ""

                Assert-MockCalled Set-EnvVar -Times 0
                $env:Path | Should -Be 'C:\Machine1;C:\User1;C:\User2'
            }

            It 'does not update PATH when AdditionalPath is whitespace' {
                Update-SessionPATH -AdditionalPath "   "

                Assert-MockCalled Set-EnvVar -Times 0
                $env:Path | Should -Be 'C:\Machine1;C:\User1;C:\User2'
            }
        }

        Context 'Mixed valid, invalid and duplicate paths' {
            It 'adds only valid, unique paths' {
                Mock Test-Path {
                    param($Path)
                    return $Path -ne "Z:\Broken"
                }

                Update-SessionPATH -AdditionalPath "C:\User2;D:\Valid;Z:\Broken;E:\Another"

                Assert-MockCalled Set-EnvVar -Exactly -Times 1 -ParameterFilter {
                    $Name -eq 'Path' -and
                    $Scope -eq [EnvironmentVariableTarget]::User -and
                    $Value -eq 'C:\User1;C:\User2;D:\Valid;E:\Another'
                }

                $env:Path | Should -Be 'C:\Machine1;C:\User1;C:\User2;D:\Valid;E:\Another'
            }
        }

        Context 'Multiple valid new paths' {
            It 'appends all new valid unique paths' {
                Update-SessionPATH -AdditionalPath "D:\One;E:\Two"

                Assert-MockCalled Set-EnvVar -Exactly -Times 1 -ParameterFilter {
                    $Name -eq 'Path' -and
                    $Scope -eq [EnvironmentVariableTarget]::User -and
                    $Value -eq 'C:\User1;C:\User2;D:\One;E:\Two'
                }

                $env:Path | Should -Be 'C:\Machine1;C:\User1;C:\User2;D:\One;E:\Two'
            }
        }

        Context 'No additional paths provided' {
            It 'only refreshes PATH with existing machine and user paths' {
                Update-SessionPATH

                Assert-MockCalled Set-EnvVar -Times 0
                $env:Path | Should -Be 'C:\Machine1;C:\User1;C:\User2'
            }
        }

        Context 'Trailing backslashes handling' {
            It 'trims trailing backslashes from paths' {
                Update-SessionPATH -AdditionalPath "D:\Valid\;E:\Another\"

                Assert-MockCalled Set-EnvVar -Exactly -Times 1 -ParameterFilter {
                    $Name -eq 'Path' -and
                    $Scope -eq [EnvironmentVariableTarget]::User -and
                    $Value -eq 'C:\User1;C:\User2;D:\Valid;E:\Another'
                }
            }
        }

        Context 'Handles empty AdditionalPath parameter' {
            It 'does not call Set-EnvVar when AdditionalPath is empty' {
                Update-SessionPATH -AdditionalPath ""

                Assert-MockCalled Set-EnvVar -Exactly -Times 0
            }
        }

        Context 'Handles invalid paths' {
            It 'ignores invalid paths when updating PATH' {
                Mock Test-Path {
                    param ($Path)
                    $result = ($Path -notlike "C:\Invalid*")
                    return $result
                }

                Update-SessionPATH -AdditionalPath "C:\InvalidPath;D:\Valid"

                Assert-MockCalled Set-EnvVar -Exactly -Times 1 -ParameterFilter {
                    $Name -eq 'Path' -and
                    $Scope -eq [EnvironmentVariableTarget]::User -and
                    $Value -eq 'C:\User1;C:\User2;D:\Valid'
                }

                $env:Path | Should -Be 'C:\Machine1;C:\User1;C:\User2;D:\Valid'
            }
        }
    }
}
