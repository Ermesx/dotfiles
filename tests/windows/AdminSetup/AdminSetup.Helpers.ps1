# Dot-sourced by the AdminSetup tests (inside BeforeAll, so TestDrive exists).
# Renders templates of the source tree with an explicit empty chezmoi config, never the user's own.
# Data (optional) overrides the template data, e.g. @{ profiles = @('shell') }; without it everything is selected.
function Invoke-ChezmoiTemplate([string]$Text, [hashtable]$Data) {
    $root = Resolve-Path "$PSScriptRoot/../../.."
    $config = Join-Path $TestDrive 'empty-chezmoi.toml'
    if (-not (Test-Path $config)) { New-Item -ItemType File -Path $config | Out-Null }

    $arguments = @('--source', $root, '--config', $config)
    if ($Data) { $arguments += @('--override-data', (ConvertTo-Json $Data -Depth 5 -Compress)) }

    $rendered = $Text | chezmoi @arguments execute-template
    $LASTEXITCODE | Should -Be 0 -Because 'chezmoi renders the template'
    $rendered -join "`n"
}

# Renders home/<Relative> into a file of the same name (without .tmpl) in TestDrive and returns its path
function Get-RenderedScript([string]$Relative, [hashtable]$Data) {
    $root = Resolve-Path "$PSScriptRoot/../../.."
    $dir = Join-Path $TestDrive ([guid]::NewGuid())
    New-Item -ItemType Directory -Path $dir | Out-Null
    $path = Join-Path $dir ((Split-Path $Relative -Leaf) -replace '\.tmpl$', '')

    Set-Content -Path $path -Value (Invoke-ChezmoiTemplate (Get-Content -Raw (Join-Path $root "home/$Relative")) $Data)
    $path
}
