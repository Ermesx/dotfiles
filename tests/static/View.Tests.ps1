#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '6.0.0' }

# The packages view (home/.chezmoitemplates/packages.tmpl): packages.yaml filtered by the stored selection
BeforeAll {
    Import-Module "$PSScriptRoot/StaticChecks.psm1" -Force
    $root = Resolve-Path "$PSScriptRoot/../.."
    $full = Get-PackagesView -Source $root
}

Describe 'packages view' {

    It 'selects everything when no selection is stored' {
        $full.profiles | Should -Contain 'base'
        $full.profiles | Should -Contain 'shell'
        $full.profiles | Should -Contain 'sdk'
        $full.profiles | Should -Contain 'containers'
        $full.profiles | Should -Contain 'apps'
        $full.profiles | Should -Contain 'ai'
        $full.scoop | Should -Contain 'extras/rider'
        $full.scoop | Should -Contain 'claude-code'
    }

    It 'selects only base and the chosen profiles' {
        $view = Get-PackagesView -Source $root -Data @{ profiles = @('shell') }

        $view.profiles | Should -HaveCount 2
        $view.profiles | Should -Contain 'base'
        $view.profiles | Should -Contain 'shell'
        $view.scoop | Should -Contain 'starship'
        $view.scoop | Should -Not -Contain 'dotnet-sdk'
        $view.modules | Should -Contain 'PSfzf'
        $view.modules | Should -Not -Contain 'Pester'
    }

    It 'merges global into the platform' {
        (Get-PackagesView -Source $root -Data @{ profiles = @('sdk') }).dotnet_tools | Should -Contain 'dotnet-ef'

        $shell = Get-PackagesView -Source $root -Data @{ profiles = @('shell') }
        $shell.yazi_plugins | Should -Contain 'yazi-rs/plugins:full-border'
        $shell.dotnet_tools | Should -BeNullOrEmpty
    }

    It 'takes only picked items of a pick profile' {
        $view = Get-PackagesView -Source $root -Data @{ profiles = @('apps'); picks = @{ apps = @('rider') } }

        $view.scoop | Should -Contain 'extras/rider'
        $view.scoop | Should -Not -Contain 'extras/postman'
    }

    It 'includes no item of a pick profile with no picks' {
        $view = Get-PackagesView -Source $root -Data @{ profiles = @('apps'); picks = @{ apps = @() } }

        $view.scoop | Should -Not -Contain 'extras/rider'
        $view.scoop | Should -Not -Contain 'extras/googlechrome'
        $view.scoop | Should -Not -Contain 'extras/postman'
        $view.scoop | Should -Not -Contain 'vagrant'
    }

    It 'ignores a stored pick that is no longer declared' {
        $view = Get-PackagesView -Source $root -Data @{ profiles = @('apps'); picks = @{ apps = @('rider', 'gone') } }

        $view.scoop | Should -Contain 'extras/rider'
        $view.scoop | Should -Not -Contain 'gone'
    }

    It 'strips buckets in tools' {
        $full.tools | Should -Contain 'vscode'
        $full.tools | Should -Contain 'rider'
        $full.tools | Should -Contain 'Hasklig-NF'
        $full.tools | Should -Contain 'PSfzf'
        $full.tools | Should -Contain 'dotnet-ef'
        $full.tools | Should -Not -Contain 'extras/vscode'
    }

    It 'has no WSL distro without sdk' {
        (Get-PackagesView -Source $root -Data @{ profiles = @('shell') }).wsl | Should -BeExactly ''
        $full.wsl | Should -BeExactly 'Ubuntu-24.04'
    }

    It 'needs the WSL platform for a distro or Rancher Desktop' {
        (Get-PackagesView -Source $root -Data @{ profiles = @('shell') }).wsl_platform | Should -BeFalse
        (Get-PackagesView -Source $root -Data @{ profiles = @('sdk') }).wsl_platform | Should -BeTrue
        (Get-PackagesView -Source $root -Data @{ profiles = @('containers') }).wsl_platform | Should -BeTrue
    }

    It 'lists items not offered yet as pending' {
        # vscode is in the offered list so the expectation holds while it moves from apps to base (#20)
        $view = Get-PackagesView -Source $root -Data @{
            profiles = @('apps')
            picks    = @{ apps = @('rider') }
            offered  = @{ apps = @('rider', 'googlechrome', 'postman', 'vscode') }
        }
        $view.pending.apps | Should -Be @('vagrant')

        $without = Get-PackagesView -Source $root -Data @{ profiles = @('apps'); picks = @{ apps = @('rider') } }
        $without.pending.PSObject.Properties | Should -BeNullOrEmpty
    }

    It 'renders the same bytes twice' {
        $first = (Invoke-ChezmoiCi -Source $root -Arguments @('execute-template') -InputText '{{ includeTemplate "packages.tmpl" . }}').Output -join "`n"
        $second = (Invoke-ChezmoiCi -Source $root -Arguments @('execute-template') -InputText '{{ includeTemplate "packages.tmpl" . }}').Output -join "`n"

        $first | Should -Not -BeNullOrEmpty
        $first | Should -BeExactly $second
    }

    It 'has unique labels in every pick profile' {
        $packages = Get-PackagesData -Source $root
        foreach ($platform in $packages.PSObject.Properties) {
            foreach ($packageProfile in $platform.Value.profiles.PSObject.Properties | Where-Object { $_.Value.pick }) {
                $labels = @($packageProfile.Value.PSObject.Properties |
                    Where-Object { $_.Name -ne 'pick' } | ForEach-Object { $_.Value } | ForEach-Object { ($_ -split '/')[-1] })
                $duplicates = @($labels | Group-Object | Where-Object Count -gt 1 | ForEach-Object Name)

                $duplicates | Should -BeNullOrEmpty -Because "$($platform.Name).$($packageProfile.Name) labels must be unique"
            }
        }
    }
}
