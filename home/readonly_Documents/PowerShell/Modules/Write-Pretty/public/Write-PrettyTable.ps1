function Write-PrettyTable {
<#
.SYNOPSIS
    Prints a formatted table to the console from an array of objects.
    
.DESCRIPTION
    Write-PrettyTable displays tabular data in a visually appealing way using ASCII borders. It automatically calculates column widths and prints headers and rows aligned for readability.
    
.PARAMETER Data
    The array of objects to display as a table. Each object's properties become columns.
    
.EXAMPLE
    $data = @(
        @{ Name = 'Alice'; Age = 30 },
        @{ Name = 'Bob'; Age = 25 }
    )
    $data | Write-PrettyTable
#>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [array]$Data
    )

    if (-not $Data) { return }

    # Get all column names (assuming all rows have the same keys)
    $headers = $Data[0].PSObject.Properties.Name

    # Calculate max width per column
    $colWidths = @{}
    foreach ($col in $headers) {
        $maxDataWidth = ($Data | ForEach-Object { "$($_.$col)".Length } | Measure-Object -Maximum).Maximum
        $colWidths[$col] = [Math]::Max($col.Length, $maxDataWidth)
    }

    # Build separator
    $sep = '+'
    foreach ($col in $headers) {
        $sep += ('-' * ($colWidths[$col] + 2)) + '+'
    }

    # Print header
    Write-Host $sep
    $line = '|'
    foreach ($col in $headers) {
        $line += ' ' + $col.PadRight($colWidths[$col]) + ' |'
    }
    Write-Host $line
    Write-Host $sep

    # Print data rows
    foreach ($row in $Data) {
        $line = '|'
        foreach ($col in $headers) {
            $value = "$($row.$col)"
            $line += ' ' + $value.PadRight($colWidths[$col]) + ' |'
        }
        Write-Host $line
    }

    # Footer separator
    Write-Host $sep
}
