[CmdletBinding()]
param (
    [string]$BRANCH = 'develop',
    [string]$GITHUB_USERNAME = 'Ermesx'
)

function Download-File {
    param (
        [string]$Url,
        [string]$Destination
    )
    $name = Split-Path -Path $Url -Leaf

    Write-Host "► Downloading $name" -ForegroundColor Cyan
    Invoke-RestMethod -Uri $Url -OutFile $Destination
}

# Resrouces
$GITHUB_URL = "https://raw.githubusercontent.com/$GITHUB_USERNAME/dotfiles/refs/heads/$BRANCH/home/dot_config/winget-dsc"
$wingets = @('packages.dsc.winget', 'windows.dsc.winget')
$dest = Join-Path $HOME ".config\winget-dsc"

if (Get-Command -Name winget -ErrorAction SilentlyContinue) {
    # Create destination directory if it doesn't exist
    if (-Not (Test-Path -Path $dest)) {
        New-Item -ItemType Directory -Path $dest | Out-Null
    }
    
    # Download winget-dsc configuration files
    $wingets | Foreach-Object { Download-File -Url "$GITHUB_URL/$_" -Destination (Join-Path $dest $_) }

    # Install packages
    Write-Host "► Installing packages" -ForegroundColor Cyan
    winget configure --enable
    $wingets | Foreach-Object {
        winget configure -f (Join-Path $dest $_) --accept-configuration-agreements --disable-interactivity --suppress-initial-details
    }

    # Refresh PATH to include user PATH additions without needing to restart the shell
    Write-Host "► Refreshing PATH" -ForegroundColor Cyan
    $userPath = [System.Environment]::GetEnvironmentVariable("PATH", "User")
    $machinePath = [System.Environment]::GetEnvironmentVariable("PATH", "Machine")
    $env:PATH = "$userPath;$machinePath"

    # Install chezmoi and apply dotfiles
    chezmoi init --apply $GITHUB_USERNAME
}
else {
    Write-Host "winget is not installed. Please install winget first." -ForegroundColor Red
    exit 1
}