[CmdletBinding()]
param (
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

$wingets = @('twpayne.chezmoi', 'microsoft.dsc', 'microsoft.powershell')

if (Get-Command -Name winget -ErrorAction SilentlyContinue) {
    
    #Self upgrade winget
    Write-Host "► Upgrading winget" -ForegroundColor Cyan
    winget upgrade winget --accept-source-agreements --accept-source-agreements --disable-interactivity | Out-Null
    
    # Install packages    
    $wingets | Foreach-Object {
        Write-Host "► Installing $_" -ForegroundColor Cyan
        winget install $_ --accept-source-agreements --accept-source-agreements --disable-interactivity | Out-Null
    }

    # Refresh PATH to include user PATH additions without needing to restart the shell
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