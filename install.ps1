[CmdletBinding()]
param (
    [string]$GITHUB_USERNAME = 'Ermesx'
)

if (Get-Command -Name winget -ErrorAction SilentlyContinue) {
    $params = @(
        '--accept-source-agreements'
        '--accept-source-agreements'
        '--disable-interactivity'
    )

    # Self upgrade winget
    Write-Host '► Upgrading winget' -ForegroundColor Cyan
    winget upgrade winget @params| Out-Null

    # Required packages to install
    $wingets = @('twpayne.chezmoi', 'microsoft.dsc', 'microsoft.powershell')

    $wingets | Foreach-Object {
        Write-Host "► Installing $_" -ForegroundColor Cyan
        winget install $_ @params | Out-Null
    }

    # Refresh PATH without needing to restart the shell
    $userPath = [System.Environment]::GetEnvironmentVariable('PATH', 'User')
    $machinePath = [System.Environment]::GetEnvironmentVariable('PATH', 'Machine')
    $env:PATH = "$userPath;$machinePath"

    # Install chezmoi and apply dotfiles
    chezmoi init --apply $GITHUB_USERNAME
}
else {
    Write-Host 'winget is not installed. Please install winget first.' -ForegroundColor Red
    exit 1
}