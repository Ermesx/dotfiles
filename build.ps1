$ErrorActionPreference = "Stop"

# Define the root directories
$sourceRoot = "src"
$destination = "build/windows"

# Exclude files with the
$excludedExtension = ".sh"
$excludedKeyword = "linux"

Write-Host "🚀 Start build for Windows in '$destination'" -ForegroundColor Cyan

# Reset the build folder if it already exists
if (Test-Path $destination) {
    Remove-Item -Recurse -Force $destination
}
New-Item -ItemType Directory -Path $destination | Out-Null

# Get all files from the src directory (excluding .sh files and files containing 'macos' in the name)
$allFiles = Get-ChildItem -Path $sourceRoot -Recurse -File | Where-Object {
    ($_.Extension.ToLower() -ne $excludedExtension) -and ($_.FullName.ToLower() -notlike "*$excludedKeyword*")
}

$totalFiles = $allFiles.Count
$counter = 0

foreach ($item in $allFiles) {
    # Determine the target path based on the source path
    $relativePath = $item.FullName -replace ".*\\$sourceRoot\\", ""
    $target = Join-Path $destination $relativePath
    $targetDir = Split-Path -Path $target -Parent
    
    if (!(Test-Path $targetDir)) {
        New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
    }
    
    Write-Host " => Copying file: $($relativePath)"
    Copy-Item -Path $item.FullName -Destination $target -Force
    
    $counter++
    Write-Progress -Activity "Copying common and windows files" -Status "$counter of $totalFiles" -PercentComplete (($counter / $totalFiles) * 100)
}

Write-Host "✅  Build for Windows completed in '$destination'" -ForegroundColor Green
