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
        # Plain output: no live line, so the captured lines are the whole report
        $script:previousCI = $env:CI
        $env:CI = 'true'
    }

    AfterAll {
        Remove-Item function:global:scoop, function:global:dotnet -ErrorAction SilentlyContinue
        if ($null -eq $script:previousCI) { Remove-Item Env:CI -ErrorAction SilentlyContinue } else { $env:CI = $script:previousCI }
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

            Mock Write-Red { }
            # The lines the module printed (information records); anything else is not output of the report
            $lines = { process { if ($_ -is [System.Management.Automation.InformationRecord]) { "$($_.MessageData)" } } }
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

                Update-Apps -Declared $d 6>&1 | Out-Null

                Should -Invoke Write-Red -ParameterFilter { $Text -like 'Not updated: git is still outdated*' }
                Should -Invoke Write-Red -Times 0 -Exactly -ParameterFilter { $Text -like 'Not updated: jq*' }
                @((Read-PackageUpdatesCache).Apps).Name | Should -Be @('jq', 'git')
            }

            It 'updates Scoop, then every app, and keeps going after a failure' {
                $out = @(Update-Apps -Declared $d 6>&1 | & $lines)

                $script:scoopCalls | Should -Be @('update', 'update git', 'update jq', 'update bat')
                $out | Should -Contain '✗ jq'
                $out | Should -Contain '✗ 1 failed: jq'
                Should -Invoke Write-Red -Times 0 -Exactly
            }

            It 'prints a done line with the version change for an app that updated' {
                $out = @(Update-Apps -Declared $d 6>&1 | & $lines)

                ($out -join "`n") | Should -Match '(?m)^✓ git\s+1\.0 → 2\.0\s+\S+$'
                $out | Should -Contain '► Updating Apps'
                ($out -join "`n") | Should -Match '(?m)^✓ 2 updated in '
            }

            It 'reports Scoop and buckets as one line without a summary' {
                $out = @(Update-Apps -Declared $d 6>&1 | & $lines)

                $out | Should -Contain '► Updating Scoop and buckets'
                @($out -match '(?m)^✓ Scoop and buckets').Count | Should -Be 1
                # The only summary lines are the ones of the app loop
                @($out -match ' updated in ').Count | Should -Be 1
            }

            It 'computes the list after updating Scoop, with the declared apps' {
                Update-Apps -Declared $d 6>&1 | Out-Null

                Should -Invoke Get-ScoopAppUpdates -Times 2 -Exactly -ParameterFilter { "$Names" -eq 'git jq bat' }
            }

            It 'keeps only the failed app in the cache and leaves the rest of it' {
                Update-Apps -Declared $d 6>&1 | Out-Null

                $cache = Read-PackageUpdatesCache
                @($cache.Apps).Name | Should -Be @('jq')
                $cache.LastRun | Should -Be $lastRun
                @($cache.Modules).Name | Should -Be @('cached-module')
                @($cache.DotnetTools).Name | Should -Be @('cached-tool')
            }

            It 'updates no app when none is outdated' {
                $script:stillOutdated = @()
                Mock Get-ScoopAppUpdates { }

                Update-Apps -Declared $d 6>&1 | Out-Null

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
                $out = @(Update-Modules -Declared $d 6>&1 | & $lines)

                Should -Invoke Update-Module -Times 2 -Exactly -ParameterFilter { $Scope -eq 'CurrentUser' }
                $out | Should -Contain '✗ PSfzf'
                ($out -join "`n") | Should -Match '(?m)^✓ posh-git'
            }

            It 'shows why a module failed' {
                $out = @(Update-Modules -Declared $d 6>&1 | & $lines)

                ($out -join "`n") | Should -Match 'locked'
            }

            It 'keeps only the failed module in the cache' {
                Update-Modules -Declared $d 6>&1 | Out-Null

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
                $out = @(Update-DotnetTools 6>&1 | & $lines)

                $script:dotnetCalls | Should -Be @('tool update -g dotnet-ef', 'tool update -g refitter')
                $out | Should -Contain '✗ refitter'
                ($out -join "`n") | Should -Match '(?m)^✓ dotnet-ef'
            }

            It 'reports a failed tool even when dotnet writes to stdout' {
                Mock dotnet {
                    "Tool 'refitter' failed to update."
                    $global:LASTEXITCODE = if ($args -contains 'refitter') { 1 } else { 0 }
                }

                $out = @(Update-DotnetTools 6>&1 | & $lines)

                $out | Should -Contain '✗ refitter'
                ($out -join "`n") | Should -Match "failed to update"
                @((Read-PackageUpdatesCache).DotnetTools).Name | Should -Be @('refitter')
            }

            It 'keeps only the failed tool in the cache' {
                Update-DotnetTools 6>&1 | Out-Null

                @((Read-PackageUpdatesCache).DotnetTools).Name | Should -Be @('refitter')
            }
        }
    }
}
