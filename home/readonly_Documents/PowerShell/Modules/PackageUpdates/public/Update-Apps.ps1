function Update-Apps {
    param(
        [hashtable]$Declared = $Global:PackageUpdatesDeclared
    )

    Write-Cyan -Text '► Updating Scoop and buckets'
    scoop update | Out-Host

    # Computed after `scoop update`, not taken from the cache, which may be hours old
    $rows = @(Get-ScoopAppUpdates -Names $Declared.Apps)
    Invoke-PackageUpdateLoop -Rows $rows -Kind 'app' -Section Apps -Update {
        param($name)
        # Scoop aborts with a non-zero exit code; it does not throw. Out-Host keeps its output
        # out of the success result.
        $global:LASTEXITCODE = 0
        scoop update $name | Out-Host
        $LASTEXITCODE -eq 0
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
