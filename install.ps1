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

    Write-Output "► Downloading $name" -ForegroundColor Cyan
    Invoke-RestMethod -Uri $Url -OutFile $Destination
}

function Get-EnvVar {
    param (
        [string]$Name,
        [System.EnvironmentVariableTarget]$Scope
    )
    return [System.Environment]::GetEnvironmentVariable($Name, $Scope)
}

# Resrouces
$GITHUB_URL = "https://raw.githubusercontent.com/$GITHUB_USERNAME/dotfiles/refs/heads/$BRANCH/home/dot_config/winget-dsc"
$wingets = @('packages.dsc.winget', 'windows.dsc.winget')
$dest = "~\.config\winget-dsc"

if (Get-Command -Name winget -ErrorAction SilentlyContinue) {
    # Download winget-dsc configuration files
    $wingets | Foreach-Object { Download-File -Url "$GITHUB_URL/$_" -Destination (Join-Path $dest $_) }

    # Install packages
    Write-Output "► Installing packages" -ForegroundColor Cyan
    winget configure --enable
    $wingets | Foreach-Object {
        winget configure -f (Join-Path $dest $_) --accept-configuration-agreements --disable-interactivity
    }

    # Refresh PATH to include user PATH additions without needing to restart the shell
    Write-Output "► Refreshing PATH" -ForegroundColor Cyan
    $userPath = Get-EnvVar -Name "PATH" -Scope "User"
    $machinePath = Get-EnvVar -Name "PATH" -Scope "Machine"
    $env:PATH = "$userPath;$machinePath"

    # Install chezmoi and apply dotfiles
    chezmoi init --apply $GITHUB_USERNAME
}
else {
    Write-Output "winget is not installed. Please install winget first." -ForegroundColor Red
    exit 1
}