function Install-LocalModule {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$SourceModulePath,

        [Parameter(Mandatory = $false)]
        [switch]$Force
    )

    # Extract the module name from the folder name
    $ModuleName = Split-Path $SourceModulePath -Leaf
           
    $manifestPath = Join-Path -Path $SourceModulePath -ChildPath "$ModuleName.psd1"
    $moduleManifest = Import-PowerShellDataFile -Path $manifestPath

    # Check if the module is already installed
    $existingModule = Get-Module -Name $ModuleName -ListAvailable
    
    if ($existingModule -And $moduleManifest.ModuleVersion -le $existingModule.Version -And -Not $Force) {
        Write-Host "👌 Module '$ModuleName' is already installed." -ForegroundColor Yellow
        return
    }
    
    # Define the destination path in the user module directory
    $pwsh5ModulesPath = Join-Path -Path "$env:USERPROFILE\Documents\WindowsPowerShell\Modules" -ChildPath $ModuleName
    $pwsh7ModulesPath = Join-Path -Path "$env:USERPROFILE\Documents\PowerShell\Modules" -ChildPath $ModuleName

    $action = if ($existingModule) { 'Updating' } else { 'Installing' }
    Write-Host "📦 $action module '$ModuleName' to: `n`t$pwsh7ModulesPath`n`t$pwsh5ModulesPath..." -ForegroundColor Cyan

    # Check if the module already exists
    if ((Test-Path $pwsh5ModulesPath) -and (Test-Path $pwsh7ModulesPath)) {
        Write-Host "⚠️ Removing existing module at `n`t$pwsh7ModulesPath`n`t$pwsh5ModulesPath..." -ForegroundColor Yellow
        Remove-Item -Recurse -Force -Path $pwsh5ModulesPath
        Remove-Item -Recurse -Force -Path $pwsh7ModulesPath
    }    

    # Copy the module directory and its contents
    Copy-Item -Path $SourceModulePath -Destination $pwsh5ModulesPath -Recurse -Force
    Copy-Item -Path $SourceModulePath -Destination $pwsh7ModulesPath -Recurse -Force

    $action = if ($existingModule) { 'updated' } else { 'installed' }
    Write-Host "✅ Module '$ModuleName' $action successfully!" -ForegroundColor Green
}
