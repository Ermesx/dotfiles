# Install the latest stable Python (updates are manual: py install --update)
Write-Host "► Installing Python" -ForegroundColor Cyan
if (-not (py list --only-managed -f=jsonl 3)) {
    py install --yes 3 | Out-Null
}
