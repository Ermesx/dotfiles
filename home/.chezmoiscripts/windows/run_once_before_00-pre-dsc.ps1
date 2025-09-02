# Install packagess and configure system
if ((Get-PSRepository -Name PSGallery).InstallationPolicy -ne 'Trusted') {
    Write-Host "► Setting PSGallery Trusted" -ForegroundColor Cyan
    Set-PSRepository -Name "PSGallery" -InstallationPolicy Trusted
}

Write-Host "► Installing Requred DSC Resources" -ForegroundColor Cyan
Install-Module PowerShellModule
Install-Module Microsoft.Windows.Settings -AllowPrerelease
Install-Module Microsoft.Windows.Developer -AllowPrerelease -AllowClobber