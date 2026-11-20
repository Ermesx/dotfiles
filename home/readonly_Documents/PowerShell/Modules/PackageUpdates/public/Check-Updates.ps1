function Check-Updates {
    param(
        [switch]$Now,
        [hashtable]$Declared = $Global:PackageUpdatesDeclared
    )

    if ($Now -and -not (Update-PackageUpdatesCache -Declared $Declared)) {
        Write-Host 'A refresh is already running; showing the last data.'
    }
    $cache = Read-PackageUpdatesCache

    if (-not $cache.LastRun) {
        Write-Host 'No update data yet. Run Check-Updates -Now.'
        return
    }

    $sections = [ordered]@{
        '__APPS__' = $cache.Apps
        '__MODULES__' = $cache.Modules
        '__DOTNET TOOLS__' = $cache.DotnetTools
    }
    foreach ($section in $sections.GetEnumerator()) {
        if ($section.Value) {
            Write-Green -Text $section.Key
            $section.Value | Write-PrettyTable
        }
    }
    Write-Host "Last checked: $($cache.LastRun.ToString('g'))"
}
