#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '6.0.0' }

# One PowerShell profile fragment per tool, loaded only for selected tools
BeforeAll {
    Import-Module "$PSScriptRoot/StaticChecks.psm1" -Force
    $root = Resolve-Path "$PSScriptRoot/../.."
    $toolsDir = Join-Path $root 'home/dot_profile/tools'
    $profileTemplate = 'home/readonly_Documents/PowerShell/Microsoft.PowerShell_profile.ps1.tmpl'

    # File names of the tool fragments a rendered profile dot-sources, in order
    function Get-SourcedFragment([string[]]$Rendered) {
        $Rendered | Where-Object { $_ -match "^\. '.*[\\/]tools[\\/]" } |
            ForEach-Object { ($_ -replace "^.*[\\/]tools[\\/]", '') -replace "'$", '' }
    }

    # The tool a fragment file belongs to: the file name without .tmpl, .ps1 and a leading zz-
    function Get-FragmentTool([string]$FileName) { $FileName -replace '\.tmpl$', '' -replace '\.ps1$', '' -replace '^zz-', '' }

    # Fragment files as they are deployed (without .tmpl)
    function Get-FragmentFile { Get-ChildItem $toolsDir -File | ForEach-Object { $_.Name -replace '\.tmpl$', '' } }
}

Describe 'tool fragments' {

    It 'has a tool in the full view for every fragment' {
        $tools = (Get-PackagesView -Source $root).tools
        $fragments = Get-FragmentFile

        $fragments | Should -Not -BeNullOrEmpty
        foreach ($fragment in $fragments) { $tools | Should -Contain (Get-FragmentTool $fragment) }
    }
}

Describe 'profile template' {

    It 'dot-sources only selected tools' {
        $rendered = Get-RenderedTemplate -Source $root -Path $profileTemplate -Data @{ profiles = @() }

        Get-SourcedFragment $rendered | Should -Contain 'chezmoi.ps1'
        Get-SourcedFragment $rendered | Should -Contain 'delta.ps1'
        Get-SourcedFragment $rendered | Should -Not -Contain 'bat.ps1'
        Get-SourcedFragment $rendered | Should -Not -Contain 'PSfzf.ps1'
        Get-SourcedFragment $rendered | Should -Not -Contain 'zz-starship.ps1'
    }

    It 'dot-sources every tool fragment in the full view' {
        # The template builds the list from the folder: every deployed fragment must also be loaded
        $sourced = @(Get-SourcedFragment (Get-RenderedTemplate -Source $root -Path $profileTemplate))

        foreach ($fragment in Get-FragmentFile) { $sourced | Should -Contain $fragment }
    }

    It 'loads the fragments in file-name order, zz- ones last, zoxide the last' {
        $names = @(Get-SourcedFragment (Get-RenderedTemplate -Source $root -Path $profileTemplate))

        $sorted = [string[]]$names
        [Array]::Sort($sorted, [StringComparer]::Ordinal)
        $names | Should -Be $sorted
        $names[-1] | Should -Be 'zz-zoxide.ps1'
        $names.IndexOf('zz-starship.ps1') | Should -BeGreaterThan -1
        $names.IndexOf('zz-starship.ps1') | Should -BeLessThan $names.IndexOf('zz-zoxide.ps1')
        # Every other fragment loads before the first zz- one
        $names.IndexOf('yazi.ps1') | Should -BeLessThan $names.IndexOf('zz-starship.ps1')
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
        $none | Should -Not -Contain '.profile/tools/zz-starship.ps1'
        $none | Should -Contain '.profile/tools/chezmoi.ps1'
        Get-ManagedPath -Source $root | Should -Contain '.profile/tools/bat.ps1'
        Get-ManagedPath -Source $root | Should -Contain '.profile/tools/zz-starship.ps1'
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

Describe 'Git location' {

    It 'has no path into C:\Program Files\Git under home/ (Git comes from Scoop)' {
        $hits = Get-ChildItem (Join-Path $root 'home') -Recurse -File |
            Select-String -SimpleMatch 'Program Files\Git' -List |
            ForEach-Object { $_.Path }

        $hits | Should -BeNullOrEmpty
    }
}
