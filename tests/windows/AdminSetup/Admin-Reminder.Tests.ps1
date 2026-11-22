#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '6.0.0' }

Describe 'admin reminder after apply' {

    BeforeAll {
        $script = Resolve-Path "$PSScriptRoot/../../../home/.chezmoiscripts/windows/run_after_zz-admin-reminder.ps1"
        $expected = Join-Path $HOME '.config\dotfiles\admin\admin-setup.ps1'

        # wsl is a native command; Mock needs a command to replace on any host
        function global:wsl { }
    }

    AfterAll {
        Remove-Item function:global:wsl -ErrorAction SilentlyContinue
    }

    BeforeEach {
        # All three present
        Mock Get-ItemProperty { [pscustomobject]@{ AllowDevelopmentWithoutDevLicense = 1 } }
        Mock Get-Service { [pscustomobject]@{ Status = 'Running' } }
        Mock wsl { $global:LASTEXITCODE = 0 }
    }

    It 'prints nothing when all three are present' {
        $out = & $script 6>&1 | Out-String

        $out.Trim() | Should -BeNullOrEmpty
    }

    It 'reminds when <Item> is missing' -ForEach @(
        @{ Item = 'Developer Mode'; Missing = { Mock Get-ItemProperty { [pscustomobject]@{ AllowDevelopmentWithoutDevLicense = 0 } } } }
        @{ Item = 'WSL'; Missing = { Mock wsl { $global:LASTEXITCODE = 1 } } }
        @{ Item = 'ssh-agent'; Missing = { Mock Get-Service { [pscustomobject]@{ Status = 'Stopped' } } } }
    ) {
        . $Missing

        $out = & $script 6>&1 | Out-String

        $out | Should -BeLike '*Administrator step needed*'
        $out | Should -BeLike '*admin-setup.ps1*'
        $out | Should -Not -BeLike '*enable-*'
    }

    It "prints an absolute, quoted path under the user's profile" {
        Mock Get-Service { [pscustomobject]@{ Status = 'Stopped' } }

        $out = & $script 6>&1 | Out-String

        $out | Should -BeLike "*-File `"$expected`"*"
        $out | Should -Not -BeLike '*~*'
        $out | Should -Not -BeLike '*$HOME*'
    }

    It 'exits 0 when the ssh-agent service does not exist' {
        Mock Get-Service { }

        $out = & $script 6>&1 | Out-String

        $out | Should -BeLike '*admin-setup.ps1*'
        $LASTEXITCODE | Should -Be 0
    }
}
