#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '6.0.0' }

BeforeDiscovery {
    # InModuleScope below runs at discovery, so the module must be loaded before BeforeAll
    Import-Module PackageUpdates -Force -DisableNameChecking
}

Describe 'Update-PackageUpdatesCache and Check-Updates' {

    BeforeAll {
        # Scoop is not installed on the host; Mock needs a command to replace
        function global:scoop { }
    }

    AfterAll {
        Remove-Item function:global:scoop -ErrorAction SilentlyContinue
    }

    InModuleScope PackageUpdates {

        BeforeEach {
            $script:CacheFile = Join-Path $TestDrive 'cache.json'
            Remove-Item $script:CacheFile -ErrorAction SilentlyContinue
            $d = @{ Apps = @('git'); Modules = @('PSfzf'); DotnetTools = @('dotnet-ef') }

            Mock scoop { $global:LASTEXITCODE = 0 }
            Mock Get-ScoopAppUpdates { [pscustomobject]@{ Name = 'git'; Old = '2.50'; New = '2.51' } }
            Mock Get-ModuleUpdates { [pscustomobject]@{ Name = 'PSfzf'; Old = '2.6.0'; New = '2.7.0' } }
            Mock Get-DotnetToolUpdates { [pscustomobject]@{ Name = 'dotnet-ef'; Old = '9.0.10'; New = '10.0.0' } }
            Mock Write-Green { }
            Mock Write-PrettyTable { }
            Mock Write-Host { }
        }

        Context 'Update-PackageUpdatesCache' {
            It 'updates Scoop, runs every check with its declared list and caches the rows' {
                Update-PackageUpdatesCache -Declared $d

                Should -Invoke scoop -Times 1 -Exactly -ParameterFilter { ($args -join ' ') -eq 'update' }
                Should -Invoke Get-ScoopAppUpdates -ParameterFilter { "$Names" -eq 'git' }
                Should -Invoke Get-ModuleUpdates -ParameterFilter { "$Names" -eq 'PSfzf' }
                Should -Invoke Get-DotnetToolUpdates -ParameterFilter { "$Ids" -eq 'dotnet-ef' }
                $cache = Read-PackageUpdatesCache
                @($cache.Apps).Count | Should -Be 1
                @($cache.Modules).Count | Should -Be 1
                @($cache.DotnetTools).Count | Should -Be 1
                ((Get-Date) - $cache.LastRun).TotalMinutes | Should -BeLessThan 1
            }

            It 'claims the refresh slot before updating Scoop' {
                Mock scoop {
                    $script:lastRunDuringUpdate = (Read-PackageUpdatesCache).LastRun
                    $global:LASTEXITCODE = 0
                }

                Update-PackageUpdatesCache -Declared $d

                $script:lastRunDuringUpdate | Should -Not -BeNullOrEmpty
                ((Get-Date) - $script:lastRunDuringUpdate).TotalMinutes | Should -BeLessThan 1
            }

            It 'still checks when scoop update fails' {
                Mock scoop { $global:LASTEXITCODE = 1 }

                Update-PackageUpdatesCache -Declared $d

                Should -Invoke Get-ScoopAppUpdates -Times 1 -Exactly
                Should -Invoke Get-ModuleUpdates -Times 1 -Exactly
                Should -Invoke Get-DotnetToolUpdates -Times 1 -Exactly
            }
        }

        Context 'Check-Updates' {
            It 'shows the cached sections and when they were checked' {
                Write-PackageUpdatesCache -Cache ([pscustomobject]@{
                    LastRun = Get-Date
                    Apps = @([pscustomobject]@{ Name = 'git'; Old = '2.50'; New = '2.51' })
                    Modules = @()
                    DotnetTools = @()
                })

                Check-Updates -Declared $d

                Should -Invoke Write-Green -Times 1 -Exactly -ParameterFilter { $Text -eq '__APPS__' }
                Should -Invoke Write-PrettyTable -Times 1 -Exactly
                Should -Invoke Write-Host -ParameterFilter { "$Object" -match '^Last checked: ' }
                Should -Invoke Get-ScoopAppUpdates -Times 0 -Exactly
            }

            It 'says there is no data yet when nothing was cached' {
                Check-Updates -Declared $d

                Should -Invoke Write-Host -ParameterFilter { "$Object" -eq 'No update data yet. Run Check-Updates -Now.' }
                Should -Invoke Write-PrettyTable -Times 0 -Exactly
            }

            It 'refreshes first with -Now and shows every section' {
                Check-Updates -Now -Declared $d

                Should -Invoke Get-DotnetToolUpdates -Times 1 -Exactly
                Should -Invoke Write-Green -ParameterFilter { $Text -eq '__APPS__' }
                Should -Invoke Write-Green -ParameterFilter { $Text -eq '__MODULES__' }
                Should -Invoke Write-Green -ParameterFilter { $Text -eq '__DOTNET TOOLS__' }
                Should -Invoke Write-PrettyTable -Times 3 -Exactly
            }
        }
    }
}
