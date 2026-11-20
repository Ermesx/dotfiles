function Update-PackageUpdatesCache {
    param(
        [hashtable]$Declared = $Global:PackageUpdatesDeclared
    )

    # Claim the refresh first, so other sessions see a fresh lastRun and do not start their own
    $cache = Read-PackageUpdatesCache
    $cache.LastRun = Get-Date
    Write-PackageUpdatesCache -Cache $cache

    # Pull Scoop and the buckets: `scoop status` only sees versions in the local bucket checkout.
    # A failure (offline, git lock) leaves the checks on the local data.
    try {
        scoop update *>$null
    }
    catch {
    }

    $cache.Apps = @(Get-ScoopAppUpdates -Names $Declared.Apps)
    $cache.Modules = @(Get-ModuleUpdates -Names $Declared.Modules)
    $cache.DotnetTools = @(Get-DotnetToolUpdates -Ids $Declared.DotnetTools)
    Write-PackageUpdatesCache -Cache $cache
}
