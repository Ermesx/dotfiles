function gi {
    <#
    .SYNOPSIS
    Generates a .gitignore file from technology presets using the Toptal gitignore API.
    
    .DESCRIPTION
    Downloads and writes a combined .gitignore for the provided list of technologies/frameworks.
    Supports receiving items from the pipeline, writing to a custom output path, and appending to an existing file.
    
    .INPUTS
    System.String[]
    You can pipe one or more technology names (e.g., 'windows', 'node') to this function.
    
    .OUTPUTS
    None
    Writes a .gitignore file to disk; no objects are emitted.
    
    .PARAMETER List
    One or more technology identifiers (e.g., 'windows', 'visualstudio', 'node', 'python').
    Accepts values from the pipeline and from remaining arguments.
    
    .PARAMETER OutputPath
    The path to the output .gitignore file. Defaults to '.gitignore' in the current directory.
    
    .PARAMETER Append
    When specified, appends the downloaded content to the target file instead of overwriting it.
    
    .EXAMPLE
    gi windows visualstudio -o .gitignore
    Downloads a .gitignore that includes Windows and Visual Studio presets and writes it to ./.gitignore.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipeline, ValueFromRemainingArguments)]
        [string[]]$List,
        [Alias('o')]
        [string]$OutputPath = '.gitignore',
        [Alias('a')]
        [switch]$Append
    )

    begin {
        $acc = @()
    }
    process {
        $acc += $List
    }
    end {
        $clean = $acc | ForEach-Object {
            if (-not [string]::IsNullOrWhiteSpace($_)) {
                $_.Trim()
            }
        } | Sort-Object -Unique
        if (-not $clean) {
            throw 'Technology list is empty.'
        }

        $params = ($clean | ForEach-Object { [Uri]::EscapeDataString($_) }) -join ','
        $uri = "https://www.toptal.com/developers/gitignore/api/$params"

        $status = $null
        try {
            $content = Invoke-RestMethod -Uri $uri -Method Get -StatusCodeVariable status -ErrorAction Stop
        }
        catch {
            throw "Download failed: $( $_.Exception.Message )`nURL: $uri"
        }
        if ($status -ne 200) {
            throw "Unexpected HTTP status: $status`nURL: $uri"
        }

        $fullPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($OutputPath)

        $old = if (Test-Path $fullPath) {
            Get-Content $fullPath -Raw
        }
        else {
            ''
        }
        $final = if ($Append -and (Test-Path $fullPath)) {
            if ( [string]::IsNullOrEmpty($old)) {
                $content
            }
            else {
                $old.TrimEnd("`r", "`n") + "`r`n" + $content
            }
        }
        else {
            $content
        }

        if ($final -eq $old) {
            Write-Host '[gig] No changes'
        }
        else {
            $tmpOld = [System.IO.Path]::GetTempFileName()
            $tmpNew = [System.IO.Path]::GetTempFileName()
            try {
                Set-Content -Path $tmpOld -Value $old   -Encoding utf8
                Set-Content -Path $tmpNew -Value $final -Encoding utf8
                & git --no-pager diff --no-index -- "$tmpOld" "$tmpNew"
            }
            finally {
                Remove-Item $tmpOld,$tmpNew -ErrorAction SilentlyContinue
            }
        }

        if ( $PSCmdlet.ShouldProcess($fullPath, ($Append ? 'Append' : 'Write'))) {
            if ($Append -and (Test-Path $fullPath)) {
                Add-Content -Path $fullPath -Value $content -Encoding utf8
            }
            else {
                Set-Content -Path $fullPath -Value $content -Encoding utf8
            }
        }
    }
}
