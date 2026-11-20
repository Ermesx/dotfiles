function Read-PackageUpdatesCache {
    # A missing, empty, half-written or otherwise invalid file means "no data", never an error
    try {
        $data = Get-Content -Path $script:CacheFile -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
        $lastRun = if ($data.lastRun) { [datetime]$data.lastRun } else { $null }
    }
    catch {
        $data = $null
        $lastRun = $null
    }

    [pscustomobject]@{
        LastRun = $lastRun
        Apps = @($data.apps | Where-Object { $_ })
        Modules = @($data.modules | Where-Object { $_ })
        DotnetTools = @($data.dotnetTools | Where-Object { $_ })
    }
}
