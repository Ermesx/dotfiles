function Test-PackageUpdatesCacheStale {
    $lastRun = (Read-PackageUpdatesCache).LastRun
    -not $lastRun -or ((Get-Date) - $lastRun) -gt $script:MaxCacheAge
}
