#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '6.0.0' }

Describe 'Complete-UserSetup' {

    BeforeAll {
        . "$PSScriptRoot/AdminSetup.Helpers.ps1"
        # The distro comes from the packages view, as the fragment's own render does
        $distro = (Invoke-ChezmoiTemplate '{{ includeTemplate "packages.tmpl" . }}' | ConvertFrom-Json).wsl
        . (Get-RenderedScript 'dot_profile/user-setup_profile.ps1.tmpl')

        # wsl and ssh-add are native commands; Mock needs a command to replace on any host
        function global:wsl { }
        function global:ssh-add { }
    }

    AfterAll {
        Remove-Item function:global:wsl, function:global:ssh-add -ErrorAction SilentlyContinue
    }

    BeforeEach {
        # Administrator step done: WSL enabled, distro listed, agent running
        Mock wsl { if ($args -contains '--status') { $global:LASTEXITCODE = 0 } else { $distro } }
        Mock Get-Service { [pscustomobject]@{ Status = 'Running' } }
        Mock ssh-add { }
        Mock Write-Host { }
    }

    It 'skips the distro install when the distro is listed' {
        Complete-UserSetup

        Should -Invoke wsl -Times 0 -Exactly -ParameterFilter { $args -contains '--install' }
    }

    It 'installs the distro when it is missing' {
        Mock wsl { if ($args -contains '--status') { $global:LASTEXITCODE = 0 } }

        Complete-UserSetup

        Should -Invoke wsl -Times 1 -Exactly -ParameterFilter { ($args -join ' ') -eq "--install -d $distro --web-download --no-launch" }
    }

    It 'loads the SSH key' {
        Complete-UserSetup

        Should -Invoke ssh-add -Times 1 -Exactly -ParameterFilter { $args[0] -eq (Join-Path $HOME '.ssh' 'id_ed25519') }
    }

    It 'does not install the distro and points at the administrator step when WSL is not enabled' {
        Mock wsl { if ($args -contains '--status') { $global:LASTEXITCODE = 1 } }

        Complete-UserSetup

        Should -Invoke wsl -Times 0 -Exactly -ParameterFilter { $args -contains '--install' }
        Should -Invoke Write-Host -ParameterFilter { $Object -like '*WSL*administrator*' }
    }

    It 'does not call ssh-add and points at the administrator step when ssh-agent is not running' {
        Mock Get-Service { [pscustomobject]@{ Status = 'Stopped' } }

        Complete-UserSetup

        Should -Invoke ssh-add -Times 0 -Exactly
        Should -Invoke Write-Host -ParameterFilter { $Object -like '*ssh-agent*administrator*' }
    }

    It 'leaves WSL_UTF8 as it was in the session' {
        $env:WSL_UTF8 = $null

        Complete-UserSetup

        $env:WSL_UTF8 | Should -BeNullOrEmpty
    }
}
