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

        # Auto draws a live line on an interactive terminal and plain lines everywhere else
        [ValidateSet('Auto', 'Live', 'Plain')]
        [string]$Mode = 'Auto'
    )

    $maxNameWidth = 40
    $total = [System.Diagnostics.Stopwatch]::StartNew()

    $live = (Resolve-ProgressMode -Mode $Mode) -eq 'Live'
    $ascii = $live -and [Console]::OutputEncoding.CodePage -ne 65001
    $erase = "`r`e[2K"
    $prefix = if ($live) { $erase } else { '' }
    $cyan = if ($live) { @{ ForegroundColor = 'Cyan' } } else { @{} }
    $red = if ($live) { @{ ForegroundColor = 'Red' } } else { @{} }
    $verbingText = if ($Verb -eq 'Updated') { 'updating' } else { 'installing' }

    Write-Host "► $Title" @cyan

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
    $liveShowing = $false
    $index = 0

    try {
        foreach ($entry in $pending) {
            $index++
            if ($live) {
                $liveText = Format-LiveLine -Index $index -Total $pending.Count -Text "$verbingText $($entry.Name)" -Width (Get-ProgressWidth) -Ascii:$ascii
                Write-Host "$erase$liveText" -NoNewline
                $liveShowing = $true
            }

            $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
            $records = [System.Collections.Generic.List[object]]::new()
            $thrown = $false
            $thrownMessage = ''

            # A stale exit code from an earlier item or from the caller must not fail this one
            $global:LASTEXITCODE = 0
            try {
                # Streamed into the list so output printed before a throw is kept
                & $Action $entry.Item *>&1 | ForEach-Object { $records.Add($_) }
            }
            catch {
                $thrown = $true
                $thrownMessage = $_.Exception.Message
            }
            $stopwatch.Stop()

            # Write-Host -NoNewline arrives as one record per piece; the pieces belong on one line
            $lines = [System.Collections.Generic.List[string]]::new()
            $open = $false
            foreach ($record in $records) {
                $continues = $record -is [System.Management.Automation.InformationRecord] -and
                    $record.MessageData -is [System.Management.Automation.HostInformationMessage] -and
                    $record.MessageData.NoNewLine
                $text = if ($record -is [System.Management.Automation.InformationRecord]) { "$($record.MessageData)" }
                elseif ($record -is [System.Management.Automation.ErrorRecord]) { $record.ToString() }
                else { (Out-String -InputObject $record).TrimEnd() }
                $parts = [string[]]($text -split '\r?\n')
                if ($open) {
                    $lines[$lines.Count - 1] += $parts[0]
                    if ($parts.Count -gt 1) { $lines.AddRange([string[]]$parts[1..($parts.Count - 1)]) }
                }
                else {
                    $lines.AddRange($parts)
                }
                $open = $continues
            }
            if ($thrown) { $lines.Add($thrownMessage) }

            if ($thrown -or $global:LASTEXITCODE -ne 0) {
                $output = ($lines -join "`n").Trim("`n")
                $failed.Add([pscustomobject]@{ Item = $entry.Item; Name = $entry.Name; Output = $output })

                Write-Host "$prefix✗ $($entry.Name)" @red
                $liveShowing = $false
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
            Write-Host "$prefix$text  $(Format-Elapsed $stopwatch.Elapsed)"
            $liveShowing = $false
        }
    }
    finally {
        # Leaves no half-drawn line behind when something unexpected escapes
        if ($liveShowing) { Write-Host $erase -NoNewline }
    }

    $total.Stop()

    # One item that simply succeeded already has its own line
    $isSingleSuccess = $done -eq 1 -and $present -eq 0 -and $failed.Count -eq 0
    if (-not $isSingleSuccess) {
        $summary = Format-Summary -Done $done -Present $present -Verb $Verb -Elapsed $total.Elapsed
        if ($summary) { Write-Host $summary }
    }
    if ($failed.Count -gt 0) {
        Write-Host "✗ $($failed.Count) failed: $($failed.Name -join ', ')" @red
    }

    [pscustomobject]@{
        Done    = $done
        Present = $present
        Failed  = $failed.ToArray()
    }
}
