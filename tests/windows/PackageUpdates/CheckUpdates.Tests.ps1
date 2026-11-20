#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '6.0.0' }

BeforeDiscovery {
    # InModuleScope below runs at discovery, so the module must be loaded before BeforeAll
    Import-Module PackageUpdates -Force -DisableNameChecking
}

Describe 'Update-PackageUpdatesCache and Check-Updates' {

    BeforeAll {
        # Scoop is not on the host and dotnet may be missing; Mock needs a command to replace
        function global:scoop { }
        function global:dotnet { }
    }

    AfterAll {
        Remove-Item function:global:scoop, function:global:dotnet -ErrorAction SilentlyContinue
    }

    InModuleScope PackageUpdates {

        BeforeEach {
            $script:CacheFile = Join-Path $TestDrive 'cache.json'
            Remove-Item $script:CacheFile -ErrorAction SilentlyContinue
            $script:LockFile = Join-Path $TestDrive "refresh-$([guid]::NewGuid()).lock"
            $d =@{ Apps = @('git'); Modules = @('PSfzf') }

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
                Should -Invoke Get-DotnetToolUpdates -Times 1 -Exactly
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

            It 'does nothing while another refresh holds the lock' {
                $held = [System.IO.File]::Open($script:LockFile, 'OpenOrCreate', 'ReadWrite', 'None')
                try {
                    Update-PackageUpdatesCache -Declared $d | Should -BeFalse
                }
                finally {
                    $held.Dispose()
                }

                Should -Invoke scoop -Times 0 -Exactly
                Should -Invoke Get-ScoopAppUpdates -Times 0 -Exactly
                (Read-PackageUpdatesCache).LastRun | Should -BeNullOrEmpty
            }

            It 'releases the lock when it is done' {
                Update-PackageUpdatesCache -Declared $d | Should -BeTrue

                Test-Path $script:LockFile | Should -BeFalse
            }

            It 'keeps the previous section when one check throws, and still runs the others' {
                Write-PackageUpdatesCache -Cache ([pscustomobject]@{
                    LastRun = (Get-Date).AddHours(-5)
                    Apps = @([pscustomobject]@{ Name = 'old-app'; Old = '1'; New = '2' })
                    Modules = @()
                    DotnetTools = @()
                })
                Mock Get-ScoopAppUpdates { throw 'scoop is not recognized' }

                Update-PackageUpdatesCache -Declared $d | Should -BeTrue

                $cache = Read-PackageUpdatesCache
                @($cache.Apps).Name | Should -Be @('old-app')
                @($cache.Modules).Name | Should -Be @('PSfzf')
                @($cache.DotnetTools).Name | Should -Be @('dotnet-ef')
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

            It 'says so with -Now when another refresh is running, and shows the last data' {
                Mock Update-PackageUpdatesCache { $false }

                Check-Updates -Now -Declared $d

                Should -Invoke Write-Host -ParameterFilter { "$Object" -eq 'A refresh is already running; showing the last data.' }
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
