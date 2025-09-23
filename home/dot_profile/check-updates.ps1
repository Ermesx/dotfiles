function Get-AppUpdates {
    try {
        Get-WinGetPackage -Source winget -ErrorAction SilentlyContinue |
            Where-Object { $_.IsUpdateAvailable } |
            ForEach-Object {
                [pscustomobject]@{
                    Name = $_.Name
                    Old = $_.InstalledVersion
                    New = $_.AvailableVersions[0]
                }
            }
    }
    catch {
        @()
    }
}

function Get-ModuleUpdates {
    try {
        Get-InstalledModule -ErrorAction SilentlyContinue |
            ForEach-Object {
                $latest = Find-Module -Name $_.Name -ErrorAction SilentlyContinue
                if ($latest -and $latest.Version -gt $_.Version) {
                    [pscustomobject]@{
                        Name = $_.Name
                        Old = $_.Version
                        New = $latest.Version
                    }
                }
            }
    }
    catch {
        @()
    }
}

function Check-Updates {
    param(
        [switch]$Now
    )

    if ($Now) {
        $apps = Get-AppUpdates
        $modules = Get-ModuleUpdates

        $Global:AppUpdatesCache = $apps
        $Global:ModuleUpdatesCache = $modules
        $Global:UpdatesCacheLastRun = Get-Date
    }
    else {
        $apps = $Global:AppUpdatesCache
        $modules = $Global:ModuleUpdatesCache
    }

    if ($apps) {
        Write-Green  "__APPS__"
        $apps | Write-PrettyTable
    }

    if ($modules) {
        Write-Green -Text "__MODULES__"
        $modules | Write-PrettyTable
    }
}

# Global caches and timestamp
$Global:AppUpdatesCache = @()
$Global:ModuleUpdatesCache = @()
$Global:UpdatesCacheLastRun = Get-Date '2000-01-01'

# Register a single timer-driven background refresh per session
$sourceId = 'CheckUpdates-Timer'
if (-not (Get-EventSubscriber -SourceIdentifier $sourceId -ErrorAction SilentlyContinue)) {
    $Global:CheckUpdatesTimer = New-Object System.Timers.Timer
    $Global:CheckUpdatesTimer.Interval = [TimeSpan]::FromHours(12).TotalMilliseconds
    $Global:CheckUpdatesTimer.AutoReset = $true

    Register-ObjectEvent -InputObject $Global:CheckUpdatesTimer -EventName Elapsed -SourceIdentifier $sourceId -Action {
        try {
            # DRY: use existing functions to refresh caches
            $apps = Get-AppUpdates
            $modules = Get-ModuleUpdates

            # Update global caches from background runspace
            $Global:AppUpdatesCache = $apps
            $Global:ModuleUpdatesCache = $modules
            $Global:UpdatesCacheLastRun = Get-Date
        }
        catch {
        }
    } | Out-Null

    $Global:CheckUpdatesTimer.Start()
}



