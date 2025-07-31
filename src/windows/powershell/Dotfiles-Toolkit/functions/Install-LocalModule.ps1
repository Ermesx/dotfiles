function Install-LocalModule {
<#
.SYNOPSIS
    Installs or updates a PowerShell module from a local source path.

.DESCRIPTION
    This function installs or updates a PowerShell module by copying it from a specified local source path to the user's module directories for both Windows PowerShell and PowerShell Core.

.PARAMETER SourceModulePath
    The path to the local source directory containing the module to be installed or updated.

.PARAMETER Force
    A switch to force the installation or update, even if the module is already installed with the same or a newer version.

.EXAMPLE
    Install-LocalModule -SourceModulePath "C:\Modules\MyModule"

    Installs the module located at "C:\Modules\MyModule" to the user's module directories.

.EXAMPLE
    Install-LocalModule -SourceModulePath "C:\Modules\MyModule" -Force

    Forces the installation of the module, overwriting any existing version.

#>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$SourceModulePath,
        [switch]$Force
    )

    # Extract the module name from the folder name
    $moduleName = Split-Path $SourceModulePath -Leaf
           
    $manifestPath = Join-Path -Path $SourceModulePath -ChildPath "$moduleName.psd1"
    $moduleManifest = Import-PowerShellDataFile -Path $manifestPath

    # Check if the module is already installed
    $existingModule = Get-Module -Name $moduleName -ListAvailable
    
    if ($existingModule -And $existingModule.Version -eq $moduleManifest.ModuleVersion -And -Not $Force) {
        Write-Pretty "👌 [Skip]" -ForegroundColor '255,255,0' -FallbackForegroundColor Yellow -NoNewline
        Write-Host " Module " -NoNewline;
        Write-Pretty "__$($moduleName)__" -NoNewline
        Write-Host " ($($existingModule.Version))" -ForegroundColor Yellow -NoNewline
        Write-Host " is already installed."
        return
    }
    
    # Define the destination path in the user module directory
    $pwsh5ModulesPath = Join-Path -Path '~\Documents\WindowsPowerShell\Modules' -ChildPath $moduleName
    $pwsh7ModulesPath = Join-Path -Path '~\Documents\PowerShell\Modules' -ChildPath $moduleName

    $action = if ($existingModule) { 'Updating' } else { 'Installing' }
    Write-Pretty "📦 $action module " -ForegroundColor '0,255,255' -FallbackForegroundColor Cyan -NoNewline
    Write-Pretty "__$($ModuleName)__" -NoNewline
    Write-Host " to: `n`t$pwsh7ModulesPath`n`t$pwsh5ModulesPath..."

    # Check if the module already exists
    if ((Test-Path $pwsh5ModulesPath) -and (Test-Path $pwsh7ModulesPath)) {
        Remove-Item -Recurse -Force -Path $pwsh5ModulesPath | Out-Null
        Remove-Item -Recurse -Force -Path $pwsh7ModulesPath | Out-Null
    }    

    # Copy the module directory and its contents
    Copy-Item -Path $SourceModulePath -Destination $pwsh5ModulesPath -Recurse -Force | Out-Null
    Copy-Item -Path $SourceModulePath -Destination $pwsh7ModulesPath -Recurse -Force | Out-Null

    $action = if ($existingModule) { 'updated' } else { 'installed' }
    Write-Pretty "✅ [OK] " -ForegroundColor '0,255,0' -FallbackForegroundColor Green -NoNewline
    Write-Pretty "__$($moduleName)__" -NoNewline
    Write-Host " module is $action successfully!" 
}
