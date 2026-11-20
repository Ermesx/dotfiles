function Get-DotnetToolUpdates {
    param(
        [string[]]$Ids = @()
    )

    $installed = try {
        (dotnet tool list -g --format json | ConvertFrom-Json -ErrorAction Stop).data
    }
    catch {
        @()
    }

    # Declared but not installed tools are skipped: installing is chezmoi's job
    foreach ($tool in $installed | Where-Object { $_.packageId -in $Ids }) {
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
