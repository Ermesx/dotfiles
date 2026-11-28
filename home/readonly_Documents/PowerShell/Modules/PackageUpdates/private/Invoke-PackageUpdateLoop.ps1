function Invoke-PackageUpdateLoop {
    # Updates each row with $Update, reports through Invoke-ProgressSteps and keeps going after a failure,
    # then leaves only the failed rows in the cache section so Check-Updates shows what is left.
    # $Update receives the item name; it fails by throwing or by a non-zero exit code of a native command.
    param(
        [object[]]$Rows = @(),
        [Parameter(Mandatory)]
        [string]$Title,
        [Parameter(Mandatory)]
        [ValidateSet('Apps', 'Modules', 'DotnetTools')]
        [string]$Section,
        [Parameter(Mandatory)]
        [scriptblock]$Update
    )

    $result = Invoke-ProgressSteps -Title $Title -Items $Rows -Verb Updated `
        -Name { param($row) $row.Name } `
        -Detail { param($row) "$($row.Old) → $($row.New)" } `
        -Action { param($row) & $Update $row.Name }

    $cache = Read-PackageUpdatesCache
    # ForEach-Object: `.Item` on the array would hit its indexer, not the items
    $cache.$Section = @($result.Failed | ForEach-Object { $_.Item })
    Write-PackageUpdatesCache -Cache $cache
}
