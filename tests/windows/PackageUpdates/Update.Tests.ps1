#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '6.0.0' }

BeforeDiscovery {
    # InModuleScope below runs at discovery, so the module must be loaded before BeforeAll
    Import-Module PackageUpdates -Force -DisableNameChecking
}

Describe 'Update-Apps, Update-Modules, Update-DotnetTools' {

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
            $lastRun = [datetime]'2026-11-20T10:00:00'
            $row = { param($name) [pscustomobject]@{ Name = $name; Old = '1.0'; New = '2.0' } }
            Write-PackageUpdatesCache -Cache ([pscustomobject]@{
                LastRun = $lastRun
                Apps = @(& $row 'cached-app')
                Modules = @(& $row 'cached-module')
                DotnetTools = @(& $row 'cached-tool')
            })
            $d = @{ Apps = @('git', 'jq', 'bat'); Modules = @('PSfzf', 'posh-git') }

            Mock Write-Host { }
            Mock Write-Cyan { }
            Mock Write-Yellow { }
            Mock Write-Green { }
            Mock Write-Red { }
        }

        Context 'Update-Apps' {
            BeforeEach {
                $script:scoopCalls = [System.Collections.Generic.List[string]]::new()
                Mock scoop {
                    $script:scoopCalls.Add($args -join ' ')
                    $global:LASTEXITCODE = if ($args -contains 'jq') { 1 } else { 0 }
                }
                # First call: before the updates; second call: the state after them
                $script:statusCalls = 0
                Mock Get-ScoopAppUpdates {
                    $script:statusCalls++
                    $names = if ($script:statusCalls -eq 1) { 'git', 'jq', 'bat' } else { $script:stillOutdated }
                    $names | ForEach-Object { & $row $_ }
                }
                $script:stillOutdated = @('jq')
            }

            It 'reports an app Scoop skipped with exit code 0 (running process) and keeps it in the cache' {
                $script:stillOutdated = @('jq', 'git')

                Update-Apps -Declared $d

                Should -Invoke Write-Red -ParameterFilter { $Text -like 'Not updated: git is still outdated*' }
                Should -Invoke Write-Red -Times 0 -Exactly -ParameterFilter { $Text -like 'Not updated: jq*' }
                @((Read-PackageUpdatesCache).Apps).Name | Should -Be @('jq', 'git')
            }

            It 'updates Scoop, then every app, and keeps going after a failure' {
                Update-Apps -Declared $d

                $script:scoopCalls | Should -Be @('update', 'update git', 'update jq', 'update bat')
                Should -Invoke Write-Red -Times 1 -Exactly
                Should -Invoke Write-Red -ParameterFilter { $Text -eq 'Failed to update app: jq' }
            }

            It 'computes the list after updating Scoop, with the declared apps' {
                Update-Apps -Declared $d

                Should -Invoke Get-ScoopAppUpdates -Times 2 -Exactly -ParameterFilter { "$Names" -eq 'git jq bat' }
            }

            It 'keeps only the failed app in the cache and leaves the rest of it' {
                Update-Apps -Declared $d

                $cache = Read-PackageUpdatesCache
                @($cache.Apps).Name | Should -Be @('jq')
                $cache.LastRun | Should -Be $lastRun
                @($cache.Modules).Name | Should -Be @('cached-module')
                @($cache.DotnetTools).Name | Should -Be @('cached-tool')
            }

            It 'updates no app when none is outdated' {
                $script:stillOutdated = @()
                Mock Get-ScoopAppUpdates { }

                Update-Apps -Declared $d

                $script:scoopCalls | Should -Be @('update')
                @((Read-PackageUpdatesCache).Apps).Count | Should -Be 0
            }
        }

        Context 'Update-Modules' {
            BeforeEach {
                Mock Get-ModuleUpdates { 'PSfzf', 'posh-git' | ForEach-Object { & $row $_ } }
                Mock Update-Module { if ($Name -eq 'PSfzf') { throw 'locked' } }
            }

            It 'updates every module in the user scope and keeps going after a failure' {
                Update-Modules -Declared $d

                Should -Invoke Update-Module -Times 2 -Exactly -ParameterFilter { $Scope -eq 'CurrentUser' }
                Should -Invoke Write-Red -Times 1 -Exactly -ParameterFilter { $Text -eq 'Failed to update module: PSfzf' }
            }

            It 'shows why a module failed' {
                Update-Modules -Declared $d

                Should -Invoke Write-Host -ParameterFilter { "$Object" -match 'locked' }
            }

            It 'keeps only the failed module in the cache' {
                Update-Modules -Declared $d

                $cache = Read-PackageUpdatesCache
                @($cache.Modules).Name | Should -Be @('PSfzf')
                @($cache.Apps).Name | Should -Be @('cached-app')
            }
        }

        Context 'Update-DotnetTools' {
            BeforeEach {
                $script:dotnetCalls = [System.Collections.Generic.List[string]]::new()
                Mock Get-DotnetToolUpdates { 'dotnet-ef', 'refitter' | ForEach-Object { & $row $_ } }
                Mock dotnet {
                    $script:dotnetCalls.Add($args -join ' ')
                    $global:LASTEXITCODE = if ($args -contains 'refitter') { 1 } else { 0 }
                }
            }

            It 'updates every tool and keeps going after a failure' {
                Update-DotnetTools

                $script:dotnetCalls | Should -Be @('tool update -g dotnet-ef', 'tool update -g refitter')
                Should -Invoke Write-Red -Times 1 -Exactly -ParameterFilter { $Text -eq 'Failed to update .NET tool: refitter' }
            }

            It 'reports a failed tool even when dotnet writes to stdout' {
                Mock dotnet {
                    "Tool 'refitter' failed to update."
                    $global:LASTEXITCODE = if ($args -contains 'refitter') { 1 } else { 0 }
                }

                Update-DotnetTools

                Should -Invoke Write-Red -Times 1 -Exactly -ParameterFilter { $Text -eq 'Failed to update .NET tool: refitter' }
                @((Read-PackageUpdatesCache).DotnetTools).Name | Should -Be @('refitter')
            }

            It 'keeps only the failed tool in the cache' {
                Update-DotnetTools

                @((Read-PackageUpdatesCache).DotnetTools).Name | Should -Be @('refitter')
            }
        }
    }
}
