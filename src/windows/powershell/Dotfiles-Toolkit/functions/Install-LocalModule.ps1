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

    # Define the destination path in the user module directory
    $TargetPath = Join-Path -Path "$env:USERPROFILE\Documents\WindowsPowerShell\Modules" -ChildPath $ModuleName

    Write-Host "📦 Installing module '$ModuleName' to: $TargetPath"

    # Check if the module already exists
    if (Test-Path $TargetPath) {
        if ($Force) {
            Write-Host "⚠️ Removing existing module at $TargetPath" -ForegroundColor Yellow
            Remove-Item -Recurse -Force -Path $TargetPath
        } else {
            Write-Error "❌ Target path already exists. Use -Force to overwrite."
            return
        }
    }

    # Ensure the parent Modules directory exists
    $ModulesDir = Split-Path $TargetPath -Parent
    if (-not (Test-Path $ModulesDir)) {
        New-Item -ItemType Directory -Path $ModulesDir | Out-Null
    }

    # Copy the module directory and its contents
    Copy-Item -Path $SourceModulePath -Destination $TargetPath -Recurse -Force

    Write-Host "✅ Module '$ModuleName' installed successfully!" -ForegroundColor Green
}
