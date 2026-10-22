[CmdletBinding()]
param (
    [string]$GITHUB_USERNAME = 'Ermesx'
)

$params = @(
    '--accept-source-agreements'
    '--accept-package-agreements'
    '--disable-interactivity'
)

# winget codes treated as success: ok, already installed, newer installed, reboot pending
$okCodes = @(0, 0x8A150061, 0x8A15010D, 0x8A15010E, 0x8A150109)

# Readable reasons for the most likely winget failures
$failReasons = @{
    0x8A150014 = 'package not found in the winget sources'
    0x8A150019 = 'administrator rights are required, run the script from an elevated shell'
    0x8A150010 = 'no installer applicable to this system'
    0x8A150011 = 'installer hash does not match the manifest'
    0x8A15006D = 'winget service is busy or unavailable, try again later'
}

if (Get-Command -Name winget -ErrorAction SilentlyContinue) {

    # Self upgrade winget
    Write-Host '► Upgrading winget' -ForegroundColor Cyan
    winget upgrade winget @params| Out-Null
}
else {
    
    # Install winget
    Write-Host '► Installing winget' -ForegroundColor Cyan
    $appInstallerPath = "$env:TEMP\Microsoft.DesktopAppInstaller.msixbundle"

    Invoke-WebRequest -Uri "https://aka.ms/getwinget" -OutFile $appInstallerPath -UseBasicParsing
    Add-AppxPackage -Path $appInstallerPath -ForceApplicationShutdown -ForceUpdateFromAnyVersion -Confirm:$false
}

# Required packages to install
$wingets = @('twpayne.chezmoi', 'microsoft.dsc', 'microsoft.powershell')

$wingets | Foreach-Object {
    Write-Host "► Installing $_" -ForegroundColor Cyan
    winget install $_ @params --no-progress | Out-Null
    if ($LASTEXITCODE -notin $okCodes) {
        $reason = $failReasons[$LASTEXITCODE]
        if (-not $reason) { $reason = "unexpected winget error, run 'winget install $_' to see the details" }
        throw ("Installing '{0}' failed: {1} (winget exit code 0x{2:X8})" -f $_, $reason, $LASTEXITCODE)
    }
}

# Refresh PATH without needing to restart the shell
$userPath = [System.Environment]::GetEnvironmentVariable('PATH', 'User')
$machinePath = [System.Environment]::GetEnvironmentVariable('PATH', 'Machine')
$env:PATH = "$userPath;$machinePath"

# Install chezmoi and apply dotfiles
chezmoi init --apply $GITHUB_USERNAME