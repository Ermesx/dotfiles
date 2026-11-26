#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '6.0.0' }

# The after-apply notice lists items added to a pick profile since the last init; it renders empty when there are none
BeforeAll {
    Import-Module "$PSScriptRoot/StaticChecks.psm1" -Force
    $root = Resolve-Path "$PSScriptRoot/../.."
    $template = Get-Content -Raw (Join-Path $root 'home/.chezmoiscripts/windows/run_after_zz-new-picks.ps1.tmpl')

    function Get-Notice([hashtable]$Data = @{}) {
        $result = Invoke-ChezmoiCi -Source $root -Arguments @('execute-template') -InputText $template -Data $Data
        $result.ExitCode | Should -Be 0 -Because ($result.Error -join "`n")
        $result.Output -join "`n"
    }
}

Describe 'new picks notice' {

    It 'renders nothing when nothing is pending' {
        # no init yet: no offered
        Get-Notice @{ profiles = @('apps', 'ai'); picks = @{ apps = @('rider'); ai = @() } } | Should -Match '^\s*$'

        # everything on offer was offered
        Get-Notice @{
            profiles = @('apps', 'ai')
            picks    = @{ apps = @('rider'); ai = @() }
            offered  = @{ apps = @('rider', 'googlechrome', 'postman', 'vagrant'); ai = @('claude-code') }
        } | Should -Match '^\s*$'
    }

    It 'lists new items per profile' {
        $out = Get-Notice @{
            profiles = @('apps', 'ai')
            picks    = @{ apps = @('rider'); ai = @('claude-code') }
            offered  = @{ apps = @('rider', 'googlechrome', 'postman'); ai = @() }
        }

        $out | Should -Match '► New items to choose from \(not installed\):'
        $out | Should -Match "(?m)^Write-Host '    ai:   claude-code'\s*$"
        $out | Should -Match "(?m)^Write-Host '    apps: vagrant'\s*$"
        $out | Should -Match "(?m)^Write-Host '  Choose with: chezmoi init --apply --prompt'\s*$"
    }

    It 'ignores unselected profiles' {
        # the view reports pending for selected pick profiles only
        Get-Notice @{ profiles = @('shell'); offered = @{ apps = @() } } | Should -Match '^\s*$'
    }
}
