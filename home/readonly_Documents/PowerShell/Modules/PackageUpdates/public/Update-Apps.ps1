function Update-Apps {
    param(
        [hashtable]$Declared = $Global:PackageUpdatesDeclared
    )

    $null = Invoke-ProgressSteps -Title 'Updating Scoop and buckets' -Items @('Scoop and buckets') -Verb Updated -Action { scoop update }

    # Computed after `scoop update`, not taken from the cache, which may be hours old
    $rows = @(Get-ScoopAppUpdates -Names $Declared.Apps)
    Invoke-PackageUpdateLoop -Rows $rows -Title 'Updating Apps' -Section Apps -Update {
        param($name)
        scoop update $name
    }
    if (-not $rows) { return }

    # Scoop skips an app with a running process and still exits 0 (pwsh and windows-terminal host
    # this session), so the state after the updates, not the exit code, decides what is left
    $failed = @((Read-PackageUpdatesCache).Apps.Name)
    $left = @(Get-ScoopAppUpdates -Names $Declared.Apps)
    foreach ($row in $left | Where-Object Name -notin $failed) {
        Write-Red -Text "Not updated: $($row.Name) is still outdated (close its running instances and run Update-Apps from another shell)"
    }
    $cache = Read-PackageUpdatesCache
    $cache.Apps = $left
    Write-PackageUpdatesCache -Cache $cache
}
