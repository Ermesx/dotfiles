function Invoke-ProgressSteps {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [string]$Title,

        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [object[]]$Items,

        # Called with the item as its only argument
        [Parameter(Mandatory)]
        [scriptblock]$Action,

        [scriptblock]$Name = { param($item) "$item" },

        [scriptblock]$Detail,

        # Items for which this returns true are counted but neither run nor listed
        [scriptblock]$IsPresent,

        [ValidateSet('Installed', 'Updated')]
        [string]$Verb = 'Installed',

        # Only plain output exists so far, so every mode behaves as Plain
        [ValidateSet('Auto', 'Live', 'Plain')]
        [string]$Mode = 'Auto'
    )

    $maxNameWidth = 40
    $total = [System.Diagnostics.Stopwatch]::StartNew()

    Write-Host "► $Title"

    # Present items are decided up front so the names of the rest can be padded to one width
    $present = 0
    $pending = [System.Collections.Generic.List[object]]::new()
    foreach ($item in $Items) {
        if ($IsPresent -and (& $IsPresent $item)) {
            $present++
        }
        else {
            $pending.Add([pscustomobject]@{ Item = $item; Name = [string](& $Name $item) })
        }
    }

    $width = 0
    foreach ($entry in $pending) {
        $width = [math]::Max($width, [math]::Min($entry.Name.Length, $maxNameWidth))
    }

    $done = 0
    $failed = [System.Collections.Generic.List[object]]::new()

    foreach ($entry in $pending) {
        $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
        $records = @()
        $thrown = $null

        # A stale exit code from an earlier item or from the caller must not fail this one
        $global:LASTEXITCODE = 0
        try {
            $records = @(& $Action $entry.Item *>&1)
        }
        catch {
            $thrown = $_.Exception.Message
        }
        $stopwatch.Stop()

        $lines = [System.Collections.Generic.List[string]]::new()
        foreach ($record in $records) {
            $text = if ($record -is [System.Management.Automation.InformationRecord]) { "$($record.MessageData)" }
            elseif ($record -is [System.Management.Automation.ErrorRecord]) { $record.ToString() }
            else { (Out-String -InputObject $record).TrimEnd() }
            $lines.AddRange([string[]]($text -split '\r?\n'))
        }
        if ($thrown) { $lines.Add($thrown) }

        if ($thrown -or $global:LASTEXITCODE -ne 0) {
            $output = ($lines -join "`n").Trim("`n")
            $failed.Add([pscustomobject]@{ Item = $entry.Item; Name = $entry.Name; Output = $output })

            Write-Host "✗ $($entry.Name)"
            if ($output) {
                foreach ($line in $output -split '\n') { Write-Host "    $line" }
            }
            continue
        }

        $done++
        $text = "✓ $($entry.Name.PadRight($width))"
        if ($Detail) {
            $detailText = & $Detail $entry.Item
            if ($detailText) { $text += "  $detailText" }
        }
        Write-Host "$text  $(Format-Elapsed $stopwatch.Elapsed)"
    }

    $total.Stop()

    # One item that simply succeeded already has its own line
    $isSingleSuccess = $done -eq 1 -and $present -eq 0 -and $failed.Count -eq 0
    if (-not $isSingleSuccess) {
        $summary = Format-Summary -Done $done -Present $present -Verb $Verb -Elapsed $total.Elapsed
        if ($summary) { Write-Host $summary }
    }
    if ($failed.Count -gt 0) {
        Write-Host "✗ $($failed.Count) failed: $($failed.Name -join ', ')"
    }

    [pscustomobject]@{
        Done    = $done
        Present = $present
        Failed  = $failed.ToArray()
    }
}
