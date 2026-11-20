function Write-PackageUpdatesCache {
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Cache
    )

    [ordered]@{
        lastRun = if ($Cache.LastRun) { ([datetime]$Cache.LastRun).ToString('o') } else { $null }
        apps = @($Cache.Apps)
        modules = @($Cache.Modules)
        dotnetTools = @($Cache.DotnetTools)
    } | ConvertTo-Json -Depth 5 | Set-Content -Path $script:CacheFile -Encoding UTF8
}
