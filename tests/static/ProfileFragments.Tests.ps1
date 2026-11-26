#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '6.0.0' }

# install-profiles R17-R22: one PowerShell profile fragment per tool, loaded only for selected tools
BeforeAll {
    Import-Module "$PSScriptRoot/StaticChecks.psm1" -Force
    $root = Resolve-Path "$PSScriptRoot/../.."
    $toolsDir = Join-Path $root 'home/dot_profile/tools'
    $profileTemplate = 'home/readonly_Documents/PowerShell/Microsoft.PowerShell_profile.ps1.tmpl'

    # Names of the tool fragments a rendered profile dot-sources, in order
    function Get-SourcedTool([string[]]$Rendered) {
        $Rendered | Where-Object { $_ -match "^\. '.*[\\/]tools[\\/]" } |
            ForEach-Object { ($_ -replace "^.*[\\/]tools[\\/]", '') -replace "\.ps1'$", '' }
    }
}

Describe 'tool fragments' {

    It 'has a tool in the full view for every fragment' {
        $tools = (Get-PackagesView -Source $root).tools
        $fragments = Get-ChildItem $toolsDir -File | ForEach-Object { $_.Name -replace '\.ps1(\.tmpl)?$', '' }

        $fragments | Should -Not -BeNullOrEmpty
        foreach ($fragment in $fragments) { $tools | Should -Contain $fragment }
    }
}

Describe 'profile template' {

    It 'dot-sources only selected tools' {
        $rendered = Get-RenderedTemplate -Source $root -Path $profileTemplate -Data @{ profiles = @() }

        Get-SourcedTool $rendered | Should -Contain 'chezmoi'
        Get-SourcedTool $rendered | Should -Contain 'delta'
        Get-SourcedTool $rendered | Should -Not -Contain 'bat'
        Get-SourcedTool $rendered | Should -Not -Contain 'PSfzf'
    } 

    It 'dot-sources every tool fragment in the full view' {
        # The load order is a fixed list in the template: a fragment missing from it is deployed but never loaded
        $sourced = @(Get-SourcedTool (Get-RenderedTemplate -Source $root -Path $profileTemplate))
        $fragments = Get-ChildItem $toolsDir -File | ForEach-Object { $_.Name -replace '\.ps1(\.tmpl)?$', '' }

        foreach ($fragment in $fragments) { $sourced | Should -Contain $fragment }
    }

    It 'loads zoxide last and starship before it' {
        $names = @(Get-SourcedTool (Get-RenderedTemplate -Source $root -Path $profileTemplate))

        $names[-1] | Should -Be 'zoxide'
        $names.IndexOf('starship') | Should -BeGreaterThan -1
        $names.IndexOf('starship') | Should -BeLessThan $names.IndexOf('zoxide')
    }

    It 'hashes the tool fragments too' {
        $bat = Join-Path $toolsDir 'bat.ps1'
        # chezmoi's include reads the file as it is on disk
        $hash = (Get-FileHash $bat -Algorithm SHA256).Hash.ToLower()

        Get-RenderedTemplate -Source $root -Path $profileTemplate | Should -Contain "# $hash"
    }
}

Describe 'deployed fragments' {

    It 'ignores fragments of unselected tools' {
        $none = Get-ManagedPath -Source $root -Data @{ profiles = @() }

        $none | Should -Not -Contain '.profile/tools/bat.ps1'
        $none | Should -Contain '.profile/tools/chezmoi.ps1'
        Get-ManagedPath -Source $root | Should -Contain '.profile/tools/bat.ps1'
    }
}

Describe 'update check and user setup' {

    It 'declares only selected apps for Check-Updates' {
        $rendered = (Get-RenderedTemplate -Source $root -Path 'home/dot_profile/check-updates.ps1.tmpl' -Data @{ profiles = @('shell') }) -join "`n"

        $rendered | Should -Match "'starship'"
        $rendered | Should -Not -Match "'dotnet-sdk'"
    }

    It 'skips the WSL part of Complete-UserSetup without a distro' {
        $rendered = (Get-RenderedTemplate -Source $root -Path 'home/dot_profile/user-setup_profile.ps1.tmpl' -Data @{ profiles = @('shell') }) -join "`n"

        $rendered | Should -Not -Match 'wsl --install'
        $rendered | Should -Match 'ssh-add'
    }
}
