# Script for Ctrl+R to search command history with fzf and show help for selected command
param([string] $Line)

$cmd = (($Line -replace "`r?`n", '').TrimStart() -split '\s+')[0]
if ( [string]::IsNullOrWhiteSpace($cmd)) {
    return
}

if ( $cmd.StartsWith('$')) {
    Invoke-Expression $cmd 2>&1 | Out-String
    return
}

$g = Get-Command -Name $cmd -ErrorAction SilentlyContinue | Select-Object -First 1
if ($g -and $g.CommandType -ne 'Application') {
    Get-Help $cmd -ErrorAction SilentlyContinue | bat -l man --style=plain | Out-String
}
else {
    & $cmd --help 2>&1 | bat -l man --style=plain | Out-String
}
