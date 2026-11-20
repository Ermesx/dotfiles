#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '6.0.0' }

BeforeDiscovery {
    # InModuleScope below runs at discovery, so the module must be loaded before BeforeAll
    Import-Module PackageUpdates -Force -DisableNameChecking
}

Describe 'PackageUpdates cache' {

    InModuleScope PackageUpdates {

        BeforeEach {
            $script:CacheFile = Join-Path $TestDrive 'cache.json'
            Remove-Item $script:CacheFile -ErrorAction SilentlyContinue
        }

        Context 'Read-PackageUpdatesCache' {
            It 'returns empty data when the file is missing' {
                $cache = Read-PackageUpdatesCache

                $cache.LastRun | Should -BeNullOrEmpty
                @($cache.Apps).Count | Should -Be 0
                @($cache.Modules).Count | Should -Be 0
                @($cache.DotnetTools).Count | Should -Be 0
            }

            It 'returns empty data for <Name> content' -ForEach @(
                @{ Name = 'empty'; Content = '' }
                @{ Name = 'invalid'; Content = '{ not json' }
                @{ Name = 'invalid lastRun'; Content = '{ "lastRun": "not-a-date", "apps": [] }' }
            ) {
                Set-Content -Path $script:CacheFile -Value $Content

                $cache = Read-PackageUpdatesCache

                $cache.LastRun | Should -BeNullOrEmpty
                @($cache.Apps).Count | Should -Be 0
            }

            It 'reads back what Write-PackageUpdatesCache wrote' {
                $lastRun = [datetime]'2026-11-20T10:00:00'
                Write-PackageUpdatesCache -Cache ([pscustomobject]@{
                    LastRun     = $lastRun
                    Apps        = @([pscustomobject]@{ Name = 'git'; Old = '2.50'; New = '2.51' })
                    Modules     = @()
                    DotnetTools = @()
                })

                $cache = Read-PackageUpdatesCache

                $cache.LastRun | Should -Be $lastRun
                @($cache.Apps).Count | Should -Be 1
                $cache.Apps[0].Name | Should -Be 'git'
                $cache.Apps[0].New | Should -Be '2.51'
                @($cache.Modules).Count | Should -Be 0
            }
        }

        Context 'Test-PackageUpdatesCacheStale' {
            It 'is stale when the file is missing' {
                Test-PackageUpdatesCacheStale | Should -BeTrue
            }

            It 'is stale when the file is invalid' {
                Set-Content -Path $script:CacheFile -Value '{ not json'

                Test-PackageUpdatesCacheStale | Should -BeTrue
            }

            It 'is stale after <Hours> hours: <Expected>' -ForEach @(
                @{ Hours = 5; Expected = $true }
                @{ Hours = 1; Expected = $false }
            ) {
                Write-PackageUpdatesCache -Cache ([pscustomobject]@{
                    LastRun = (Get-Date).AddHours(-$Hours); Apps = @(); Modules = @(); DotnetTools = @()
                })

                Test-PackageUpdatesCacheStale | Should -Be $Expected
            }
        }
    }
}
