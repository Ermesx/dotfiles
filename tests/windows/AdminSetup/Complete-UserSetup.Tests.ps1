#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '6.0.0' }

Describe 'Complete-UserSetup' {

    BeforeAll {
        $root = Resolve-Path "$PSScriptRoot/../../.."
        $distro = (chezmoi --source $root data --format json | ConvertFrom-Json).packages.windows.profiles.sdk.wsl
        $fragment = Join-Path $TestDrive 'user-setup.ps1'
        Get-Content -Raw (Join-Path $root 'home/dot_profile/user-setup_profile.ps1.tmpl') |
            chezmoi --source $root execute-template | Set-Content $fragment
        . $fragment

        # wsl and ssh-add are native commands; Mock needs a command to replace on any host
        function global:wsl { }
        function global:ssh-add { }
    }

    AfterAll {
        Remove-Item function:global:wsl, function:global:ssh-add -ErrorAction SilentlyContinue
    }

    BeforeEach {
        Mock ssh-add { }
        Mock Write-Host { }
    }

    It 'skips the distro install when the distro is listed' {
        Mock wsl { $distro }

        Complete-UserSetup

        Should -Invoke wsl -Times 0 -Exactly -ParameterFilter { $args -contains '--install' }
    }

    It 'installs the distro when it is missing' {
        Mock wsl { }

        Complete-UserSetup

        Should -Invoke wsl -Times 1 -Exactly -ParameterFilter { ($args -join ' ') -eq "--install -d $distro --web-download --no-launch" }
    }

    It 'loads the SSH key' {
        Mock wsl { $distro }

        Complete-UserSetup

        Should -Invoke ssh-add -Times 1 -Exactly -ParameterFilter { $args[0] -eq (Join-Path $HOME '.ssh' 'id_ed25519') }
    }
}
