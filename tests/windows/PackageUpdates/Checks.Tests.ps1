#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '6.0.0' }

BeforeDiscovery {
    # InModuleScope below runs at discovery, so the module must be loaded before BeforeAll
    Import-Module PackageUpdates -Force -DisableNameChecking
}

Describe 'PackageUpdates checks' {

    BeforeAll {
        # Scoop is not installed on the host; Mock needs a command to replace
        function global:scoop { }
    }

    AfterAll {
        Remove-Item function:global:scoop -ErrorAction SilentlyContinue
    }

    InModuleScope PackageUpdates {

        Context 'Get-ScoopAppUpdates' {
            BeforeAll {
                function New-StatusRow($Name, $Installed, $Latest, $Info = '') {
                    [pscustomobject]@{
                        Name = $Name
                        'Installed Version' = $Installed
                        'Latest Version' = $Latest
                        'Missing Dependencies' = ''
                        Info = $Info
                    }
                }
                Mock scoop {
                    'Scoop is up to date.'
                    New-StatusRow 'git' '2.50' '2.51'
                    New-StatusRow 'hasklig-nf' '3.3' '3.4'
                    New-StatusRow 'jq' '1.7' '1.8' 'Held package'
                    New-StatusRow 'fzf' '0.60' '0.61'
                    New-StatusRow 'bat' '0.25' '' 'Install failed'
                }
            }

            It 'keeps only declared, outdated, not held apps, ignoring name case' {
                $rows = @(Get-ScoopAppUpdates -Names 'git', 'Hasklig-NF', 'jq', 'bat')

                $rows.Name | Should -Be @('git', 'hasklig-nf')
                $rows[0].Old | Should -Be '2.50'
                $rows[0].New | Should -Be '2.51'
            }

            It 'reads the local status' {
                Get-ScoopAppUpdates -Names 'git' | Out-Null

                Should -Invoke scoop -ParameterFilter { $args -contains 'status' -and $args -contains '--local' }
            }
        }

        Context 'Get-ModuleUpdates' {
            BeforeAll {
                Mock Get-InstalledModule {
                    switch ($Name) {
                        'PSfzf' { [pscustomobject]@{ Name = 'PSfzf'; Version = [version]'2.6.0' } }
                        'posh-git' { [pscustomobject]@{ Name = 'posh-git'; Version = [version]'1.1.0' } }
                        default { throw "No match was found for '$Name'" }
                    }
                }
                Mock Find-Module {
                    switch ($Name) {
                        'PSfzf' { [pscustomobject]@{ Name = 'PSfzf'; Version = [version]'2.7.0' } }
                        'posh-git' { [pscustomobject]@{ Name = 'posh-git'; Version = [version]'1.1.0' } }
                    }
                }
            }

            It 'reports a declared module with a newer Gallery version' {
                $rows = @(Get-ModuleUpdates -Names 'PSfzf', 'posh-git', 'Pester')

                $rows.Count | Should -Be 1
                $rows[0].Name | Should -Be 'PSfzf'
                "$($rows[0].Old)" | Should -Be '2.6.0'
                "$($rows[0].New)" | Should -Be '2.7.0'
            }

            It 'queries the Gallery only for installed declared modules' {
                Get-ModuleUpdates -Names 'PSfzf', 'posh-git', 'Pester' | Out-Null

                Should -Invoke Find-Module -Times 2 -Exactly
                Should -Invoke Find-Module -Times 0 -Exactly -ParameterFilter { $Name -eq 'Pester' }
            }
        }

        Context 'Get-NuGetLatestStableVersion' {
            It 'returns the highest stable version from the lowercased id' {
                Mock Invoke-RestMethod { @{ versions = @('9.0.10', '10.0.0', '10.0.1-preview.1') } }

                Get-NuGetLatestStableVersion -Id 'Dotnet-EF' | Should -Be ([version]'10.0.0')
                Should -Invoke Invoke-RestMethod -ParameterFilter {
                    $Uri -eq 'https://api.nuget.org/v3-flatcontainer/dotnet-ef/index.json'
                }
            }

            It 'returns nothing when the request fails' {
                Mock Invoke-RestMethod { throw 'offline' }

                Get-NuGetLatestStableVersion -Id 'dotnet-ef' | Should -BeNullOrEmpty
            }
        }

        Context 'Get-DotnetToolUpdates' {
            BeforeAll {
                Mock dotnet {
                    '{"version":1,"data":[{"packageId":"dotnet-ef","version":"9.0.10"},{"packageId":"refitter","version":"1.6.5"},{"packageId":"upgrade-assistant","version":"1.0.518"}]}'
                }
                Mock Get-NuGetLatestStableVersion {
                    switch ($Id) {
                        'dotnet-ef' { [version]'10.0.0' }
                        default { $null }
                    }
                }
            }

            It 'reports declared installed tools with a newer stable version' {
                $rows = @(Get-DotnetToolUpdates -Ids 'dotnet-ef', 'refitter', 'dotnet-trace')

                $rows.Count | Should -Be 1
                $rows[0].Name | Should -Be 'dotnet-ef'
                "$($rows[0].Old)" | Should -Be '9.0.10'
                "$($rows[0].New)" | Should -Be '10.0.0'
            }

            It 'queries NuGet only for installed declared tools' {
                Get-DotnetToolUpdates -Ids 'dotnet-ef', 'refitter', 'dotnet-trace' | Out-Null

                Should -Invoke Get-NuGetLatestStableVersion -Times 2 -Exactly
                Should -Invoke Get-NuGetLatestStableVersion -Times 0 -Exactly -ParameterFilter {
                    $Id -in 'upgrade-assistant', 'dotnet-trace'
                }
            }

            It 'lists the global tools as JSON' {
                Get-DotnetToolUpdates -Ids 'dotnet-ef' | Out-Null

                Should -Invoke dotnet -ParameterFilter { ($args -join ' ') -eq 'tool list -g --format json' }
            }
        }
    }
}
