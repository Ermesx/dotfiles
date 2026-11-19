$ErrorActionPreference = 'Stop'

Write-Host "► Applying user settings" -ForegroundColor Cyan

$path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'
$settings = @{ HideFileExt = 0; Hidden = 1; ShowSecondsInSystemClock = 1 }
$changed = $false

foreach ($name in $settings.Keys) {
    $current = Get-ItemPropertyValue -Path $path -Name $name -ErrorAction SilentlyContinue
    if ($current -ne $settings[$name]) {
        Set-ItemProperty -Path $path -Name $name -Value $settings[$name] -Type DWord
        $changed = $true
    }
}

if ($changed) { Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue }
