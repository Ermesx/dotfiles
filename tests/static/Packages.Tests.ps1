#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '6.0.0' }

BeforeAll {
    Import-Module "$PSScriptRoot/StaticChecks.psm1" -Force
    $root = Resolve-Path "$PSScriptRoot/../.."
    $packages = Get-PackagesData -Source $root
}

Describe 'packages.yaml schema' {

    It 'accepts the repo packages' {
        Get-PackagesSchemaProblem -Packages $packages | Should -BeNullOrEmpty
    }

    It 'reports <Case>' -ForEach @(
        @{ Case = 'a Linux method on Windows';     Key = 'brew';   Json = '{"windows":{"profiles":{"base":{"brew":["git"]}}}}' }
        @{ Case = 'a Windows method in global';    Key = 'scoop';  Json = '{"global":{"profiles":{"sdk":{"scoop":["git"]}}}}' }
        @{ Case = 'an unknown platform';           Key = 'macos';  Json = '{"macos":{"profiles":{}}}' }
        @{ Case = 'a platform key besides profiles'; Key = 'extra'; Json = '{"windows":{"profiles":{},"extra":{}}}' }
        @{ Case = 'pick on the profiles node';     Key = 'pick';   Json = '{"windows":{"profiles":{"pick":true}}}' }
        @{ Case = 'pick that is not a boolean';    Key = 'pick';   Json = '{"windows":{"profiles":{"apps":{"pick":"yes","scoop":["vscode"]}}}}' }
        @{ Case = 'wsl as a list';                 Key = 'wsl';    Json = '{"windows":{"profiles":{"sdk":{"wsl":["a","b"]}}}}' }
        @{ Case = 'a method as a scalar';          Key = 'scoop';  Json = '{"windows":{"profiles":{"base":{"scoop":"git"}}}}' }
        @{ Case = 'a platform without profiles';   Key = 'profiles'; Json = '{"windows":{}}' }
        @{ Case = 'null profiles';                 Key = 'profiles'; Json = '{"windows":{"profiles":null}}' }
    ) {
        $problems = @(Get-PackagesSchemaProblem -Packages ($Json | ConvertFrom-Json))

        $problems.Count | Should -Be 1
        $problems[0] | Should -BeLike "*$Key*"
    }
}

Describe 'Scoop items' {

    It 'finds every Scoop item of the repo' {
        $items = @($packages.windows.profiles.PSObject.Properties.Value | ForEach-Object { $_.scoop } | Where-Object { $_ })

        $items.Count | Should -BeGreaterThan 0
        Get-ScoopItemProblem -Item $items | Should -BeNullOrEmpty
    }

    It 'reports a missing manifest' {
        (Get-ScoopItemProblem -Item 'main/no-such-app-xyz').Problem | Should -Be 'no manifest'
    }

    It 'reports a server error as a network error' {
        Mock Invoke-WebRequest -ModuleName StaticChecks { [pscustomobject]@{ StatusCode = 503 } }
        Mock Start-Sleep -ModuleName StaticChecks { }

        $result = Get-ScoopItemProblem -Item 'main/git' -KnownBucket @{ main = 'https://github.com/ScoopInstaller/Main' }

        $result.Problem | Should -Match '^network error 503'
        Should -Invoke Invoke-WebRequest -ModuleName StaticChecks -Times 3 -Exactly
    }

    It 'reports an unknown bucket without a request' {
        Mock Invoke-WebRequest -ModuleName StaticChecks { }

        $result = Get-ScoopItemProblem -Item 'nosuch/app' -KnownBucket @{ main = 'https://github.com/ScoopInstaller/Main' }

        $result.Problem | Should -Be 'unknown bucket'
        Should -Invoke Invoke-WebRequest -ModuleName StaticChecks -Times 0 -Exactly
    }
}
