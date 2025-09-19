function Write-PrettyTable {
    <#
.SYNOPSIS
    Prints a formatted table to the console from an array of objects.

.DESCRIPTION
    Write-PrettyTable displays tabular data in a visually appealing way using ASCII borders. It automatically calculates column widths and prints headers and rows aligned for readability.

.PARAMETER Data
    The object(s) to display as a table. Accepts input from the pipeline. Each object's properties become columns.

.EXAMPLE
    $data = @(
        @{ Name = 'Alice'; Age = 30 },
        @{ Name = 'Bob'; Age = 25 }
    )
    $data | Write-PrettyTable
#>
    [CmdletBinding()]
    param (
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [object]$Data
    )

    begin {
        # Accumulator for all rows and metadata calculated incrementally
        $allData = @()
        $headers = $null
        $colWidths = @{ }
    }

    process {
        if ($null -eq $Data) {
            return
        }

        # Normalize to a list in case an array is passed as a single argument
        $rows = if ($Data -is [System.Array]) {
            $Data
        }
        else {
            @($Data)
        }

        foreach ($row in $rows) {
            if (-not $row) {
                continue
            }

            # Initialize headers from the first row encountered
            if (-not $headers) {
                if ($row -is [System.Collections.IDictionary]) {
                    $headers = @($row.Keys)
                }
                else {
                    $headers = ($row.PSObject.Properties | Where-Object { $_.MemberType -in 'NoteProperty', 'Property' } | Select-Object -ExpandProperty Name)
                    if (-not $headers) {
                        $headers = $row.PSObject.Properties.Name
                    }
                }
                foreach ($col in $headers) {
                    # At least the header width
                    $colWidths[$col] = [Math]::Max($col.Length, 0)
                }
            }

            # Update column widths incrementally based on this row
            foreach ($col in $headers) {
                $value = if ($row -is [System.Collections.IDictionary]) {
                    "$($row[$col])"
                }
                else {
                    "$(($row.$col))"
                }
                $len = if ($null -eq $value) {
                    0
                }
                else {
                    $value.Length
                }
                if ($colWidths[$col] -lt $len) {
                    $colWidths[$col] = $len
                }
                if ($colWidths[$col] -lt $col.Length) {
                    $colWidths[$col] = $col.Length
                }
            }

            # Store the row
            $allData += $row
        }
    }

    end {
        if (-not $allData -or -not $headers) {
            return
        }

        # Build separator
        $sep = '+'
        foreach ($col in $headers) {
            $sep += ('-' * ($colWidths[$col] + 2)) + '+'
        }

        # Print header
        Write-Host $sep
        # Start of header line: print separators in default color, header text in cyan
        Write-Host -NoNewline '|'
        foreach ($col in $headers) {
            Write-Host -NoNewline ' '
            Write-Cyan -Text ($col.PadRight($colWidths[$col])) -NoNewLine
            Write-Host -NoNewline ' |'
        }
        Write-Host
        Write-Host $sep

        # Print data rows
        foreach ($row in $allData) {
            $line = '|'
            foreach ($col in $headers) {
                $value = if ($row -is [System.Collections.IDictionary]) {
                    "$($row[$col])"
                }
                else {
                    "$(($row.$col))"
                }
                if ($null -eq $value) {
                    $value = ''
                }
                $line += ' ' + $value.PadRight($colWidths[$col]) + ' |'
            }
            Write-Host $line
        }

        # Footer separator
        Write-Host $sep
    }
}
