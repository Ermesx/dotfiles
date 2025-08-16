function Install-LocalModule {
<#
.SYNOPSIS
    Installs or updates a PowerShell module from a local source path.

.DESCRIPTION
    This function installs or updates a PowerShell module by copying it from a specified local source path to the user's module directories for Windows PowerShell or PowerShell Core based on the specified version.

.PARAMETER SourceModulePath
    The path to the local source directory containing the module to be installed or updated.

.PARAMETER Version
    The PowerShell version to install the module for. Valid values are 5 (Windows PowerShell) or 7 (PowerShell Core). Defaults to 7.

.PARAMETER Force
    A switch to force the installation or update, even if the module is already installed with the same version.

.EXAMPLE
    Install-LocalModule -SourceModulePath "C:\Modules\MyModule"

    Installs the module located at "C:\Modules\MyModule" to the PowerShell 7 modules directory.

.EXAMPLE
    Install-LocalModule -SourceModulePath "C:\Modules\MyModule" -Version 5

    Installs the module located at "C:\Modules\MyModule" to the Windows PowerShell modules directory.

.EXAMPLE
    Install-LocalModule -SourceModulePath "C:\Modules\MyModule" -Force

    Forces the installation of the module, overwriting any existing version.

#>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$SourceModulePath,
        [ValidateSet(5, 7)]
        [int]$Version = 7,
        [switch]$Force
    )

    # Extract the module name from the folder name
    $moduleName = Split-Path $SourceModulePath -Leaf

    $t = Get-PadLength $moduleName
           
    $manifestPath = Join-Path -Path $SourceModulePath -ChildPath "$moduleName.psd1"
    $moduleManifest = Import-PowerShellDataFile -Path $manifestPath

    # Check if the module is already installed
    $existingModule = Get-Module -Name $moduleName -ListAvailable
    
    if ($existingModule -And $existingModule.Version -eq $moduleManifest.ModuleVersion -And -Not $Force) {
        Write-Yellow "👌 [Skip] " -NoNewline
        Write-Pretty "__$($moduleName)__$t" -NoNewline
        Write-Host "($($existingModule.Version))" -ForegroundColor Yellow
        return
    }
    
    # Define the destination path in the user module directory
    $localModulesPath = if ($version -eq 7) { '~\Documents\PowerShell\Modules' } else { '~\Documents\WindowsPowerShell\Modules' }
    $modulePath = Join-Path -Path $localModulesPath -ChildPath $moduleName

    $action = if ($existingModule) { 'Upgrading' } else { 'Installing' }
    Write-Cyan "🌀 $action module" -NoNewline
    Write-Pretty "__$($ModuleName)__" -NoNewline
    Write-Host "..." -NoNewline

    # Remove existing module directory if they exist
    if (Test-Path $modulePath) {
        Remove-Item -Recurse -Force -Path $modulePath | Out-Null
    }

    # Copy the module directory and its contents
    Copy-Item -Path $SourceModulePath -Destination $modulePath -Recurse -Force | Out-Null

    $latestVersion = $moduleManifest.ModuleVersion

    Write-Green "`r✅ [OK]   " -NoNewline
    Write-Pretty "__$($moduleName)__$t" -NoNewline
    if ($existingModule)
    {
        Write-Host "($($existingModule.Version)" -ForegroundColor Cyan -NoNewline
        Write-Red " => " -NoNewline;
        Write-Yellow "$latestVersion" -NoNewline
        Write-Host ")" -ForegroundColor Cyan
    }
    else {
        Write-Yellow "($latestVersion)"
    }
}
