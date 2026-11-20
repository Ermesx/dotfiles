function Update-PackageUpdatesCache {
    # Returns $false without doing anything when another refresh is running
    param(
        [hashtable]$Declared = $Global:PackageUpdatesDeclared
    )

    # An exclusive handle is the claim: a second opener (another session or thread job) fails at once,
    # and the OS releases it even if this process dies, so there is no stale lock to clean up
    try {
        # FileOptions typed explicitly: a plain string would bind to the (bool useAsync) overload
        $lock = [System.IO.FileStream]::new($script:LockFile, [System.IO.FileMode]::OpenOrCreate,
            [System.IO.FileAccess]::ReadWrite, [System.IO.FileShare]::None, 1, [System.IO.FileOptions]::DeleteOnClose)
    }
    catch [System.IO.IOException] {
        return $false
    }

    try {
        # Mark the cache fresh first, so other sessions' timers do not even try until the next window
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

        # One failing check (tool missing, Gallery down) keeps its previous section and does not stop the others
        $checks = [ordered]@{
            Apps = { Get-ScoopAppUpdates -Names $Declared.Apps }
            Modules = { Get-ModuleUpdates -Names $Declared.Modules }
            DotnetTools = { Get-DotnetToolUpdates }
        }
        foreach ($check in $checks.GetEnumerator()) {
            try {
                $cache.($check.Key) = @(& $check.Value)
            }
            catch {
            }
        }
        Write-PackageUpdatesCache -Cache $cache
        $true
    }
    finally {
        $lock.Dispose()
    }
}
