function Read-PackageUpdatesCache {
    # A missing, empty or half-written file means "no data", never an error
    $data = try {
        Get-Content -Path $script:CacheFile -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
    }
    catch {
        $null
    }

    $lastRun = if ($data.lastRun) { [datetime]$data.lastRun } else { $null }
    [pscustomobject]@{
        LastRun = $lastRun
        Apps = @($data.apps | Where-Object { $_ })
        Modules = @($data.modules | Where-Object { $_ })
        DotnetTools = @($data.dotnetTools | Where-Object { $_ })
    }
}
