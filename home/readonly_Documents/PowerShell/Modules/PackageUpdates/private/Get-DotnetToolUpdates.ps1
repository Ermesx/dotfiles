function Get-DotnetToolUpdates {
    # Every installed global tool, declared in packages.yaml or not: updating a .NET tool affects
    # nothing outside it, unlike an app installed outside the dotfiles
    $installed = try {
        (dotnet tool list -g --format json | ConvertFrom-Json -ErrorAction Stop).data
    }
    catch {
        @()
    }

    foreach ($tool in $installed) {
        $latest = Get-NuGetLatestStableVersion -Id $tool.packageId
        if ($latest -and $latest -gt [version]$tool.version) {
            [pscustomobject]@{
                Name = $tool.packageId
                Old = $tool.version
                New = "$latest"
            }
        }
    }
}
