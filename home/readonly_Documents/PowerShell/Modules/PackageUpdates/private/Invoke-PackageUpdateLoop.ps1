function Invoke-PackageUpdateLoop {
    # Updates each row with $Update (returns $true on success), reports failures and keeps going,
    # then leaves only the failed rows in the cache section so Check-Updates shows what is left
    param(
        [object[]]$Rows = @(),
        [Parameter(Mandatory)]
        [string]$Kind,
        [Parameter(Mandatory)]
        [ValidateSet('Apps', 'Modules', 'DotnetTools')]
        [string]$Section,
        [Parameter(Mandatory)]
        [scriptblock]$Update
    )

    $failed = foreach ($row in $Rows) {
        Write-Host " - Updating $($row.Name) [" -NoNewline
        Write-Yellow -Text "$($row.Old)" -NoNewLine
        Write-Host ' => ' -NoNewline
        Write-Green -Text "$($row.New)" -NoNewLine
        Write-Host ']'

        $ok = try {
            & $Update $row.Name
        }
        catch {
            Write-Host "   $($_.Exception.Message)"
            $false
        }
        if (-not $ok) {
            Write-Red -Text "Failed to update ${Kind}: $($row.Name)"
            $row
        }
    }

    $cache = Read-PackageUpdatesCache
    $cache.$Section = @($failed)
    Write-PackageUpdatesCache -Cache $cache
}
