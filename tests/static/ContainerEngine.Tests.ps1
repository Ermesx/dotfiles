#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '6.0.0' }

# ADR-0004: Rancher Desktop is the only container engine and docker CLI
BeforeAll {
    Import-Module "$PSScriptRoot/StaticChecks.psm1" -Force
    $root = Resolve-Path "$PSScriptRoot/../.."
    $packages = Get-PackagesData -Source $root
    $seed = Join-Path $root 'home/readonly_AppData/Local/rancher-desktop/create_settings.json'
}

Describe 'one docker CLI' {

    It 'declares no Scoop docker client on Windows' {
        $apps = @($packages.windows.profiles.PSObject.Properties.Value |
            ForEach-Object { $_.scoop } | Where-Object { $_ } | ForEach-Object { ($_ -split '/')[-1] })

        $apps | Should -Not -Contain 'docker'
        $apps | Should -Not -Contain 'docker-compose'
        $apps | Should -Not -Contain 'docker-buildx'
    }

    It 'declares Rancher Desktop in the containers profile' {
        $packages.windows.profiles.containers.scoop | Should -Contain 'extras/rancher-desktop'
        $packages.windows.profiles.containers.pick | Should -BeNullOrEmpty
    }
}

Describe 'Rancher settings seed' {

    It 'seeds the settings once' {
        $managed = InModuleScope StaticChecks -Parameters @{ Source = "$root" } { Get-ManagedPath -Source $Source -SourceRelative }

        $managed | Should -Contain 'readonly_AppData/Local/rancher-desktop/create_settings.json'
    }

    It 'sets <Path> to <Value>' -ForEach @(
        @{ Path = 'version'; Value = 19 }
        @{ Path = 'containerEngine.name'; Value = 'moby' }
        @{ Path = 'kubernetes.enabled'; Value = $false }
    ) {
        $node = Get-Content -Raw $seed | ConvertFrom-Json
        foreach ($key in $Path -split '\.') { $node = $node.$key }

        $node | Should -Be $Value
    }

    It 'leaves updates and start-up to Rancher' {
        (Get-Content -Raw $seed | ConvertFrom-Json).PSObject.Properties.Name | Should -Not -Contain 'application'
    }

    It 'manages no docker config or context' {
        $managed = InModuleScope StaticChecks -Parameters @{ Source = "$root" } { Get-ManagedPath -Source $Source }

        $managed | Where-Object { $_ -like '.docker*' } | Should -BeNullOrEmpty
    }
}

Describe 'PowerShell profile' {

    BeforeAll {
        $template = Get-Content -Raw (Join-Path $root 'home/readonly_Documents/PowerShell/Microsoft.PowerShell_profile.ps1.tmpl')

        function Get-RenderedProfile([switch]$NoCi) {
            InModuleScope StaticChecks -Parameters @{ Source = "$root"; Text = $template; NoCi = [bool]$NoCi } {
                (Invoke-ChezmoiCi -Source $Source -Arguments @('execute-template') -InputText $Text -NoCi:$NoCi).Output
            }
        }
    }

    It 'imports no module of a profile skipped in CI' {
        $rendered = Get-RenderedProfile

        $rendered | Should -Not -Contain "Import-Module -Name 'DockerCompletion'"
        $rendered | Should -Contain "Import-Module -Name 'posh-git'"
    }

    It 'imports the containers modules on a real machine' {
        Get-RenderedProfile -NoCi | Should -Contain "Import-Module -Name 'DockerCompletion'"
    }
}

Describe 'ReadMe package table' {

    It 'lists the container apps under containers' {
        $readme = Get-Content (Join-Path $root 'ReadMe.md')
        $start = [array]::IndexOf($readme, '<!-- BEGIN:packages -->')
        $end = [array]::IndexOf($readme, '<!-- END:packages -->')
        $table = $readme[$start..$end]

        $table | Where-Object { $_ -match '\(extras/rancher-desktop\)\s*\|\s*containers\s*\|' } | Should -Not -BeNullOrEmpty
        $table | Where-Object { $_ -match '\((docker|docker-compose|docker-buildx)\)' } | Should -BeNullOrEmpty
    }
}
