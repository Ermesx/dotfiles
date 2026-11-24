#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '6.0.0' }

BeforeAll {
    $root = Resolve-Path "$PSScriptRoot/../.."
    $script = Join-Path $root 'home/.chezmoiscripts/windows/run_onchange_before_01-scoop.ps1.tmpl'
    $config = Join-Path $TestDrive 'empty.toml'
    Set-Content -Path $config -Value ''

    function Get-ScoopScript([string]$ci) {
        $previous = $env:CI
        try {
            $env:CI = $ci
            Get-Content -Raw $script | chezmoi --config $config --source $root execute-template
        } finally {
            $env:CI = $previous
        }
    }
}

# Heavy GUI apps install only on real machines and the VM; the static layer still checks their manifests
Describe 'profiles skipped in CI' {

    It 'installs no app of a skipped profile when CI is true' {
        Get-ScoopScript 'true' | Should -Not -Contain 'scoop install extras/rider'
    }

    It 'still installs the other profiles when CI is true' {
        Get-ScoopScript 'true' | Should -Contain 'scoop install git'
    }

    It 'installs every profile on a real machine' {
        Get-ScoopScript '' | Should -Contain 'scoop install extras/rider'
    }

    It 'installs no container app when CI is true' {
        $script = Get-ScoopScript 'true'

        $script | Should -Not -Contain 'scoop install extras/rancher-desktop'
        $script | Should -Not -Contain 'scoop install lazydocker'
    }

    It 'installs Rancher Desktop on a real machine' {
        Get-ScoopScript '' | Should -Contain 'scoop install extras/rancher-desktop'
    }
}
