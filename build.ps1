$ErrorActionPreference = "Stop"

# Define the root directories
$sourceRoot = "src"
$destination = "build/windows"

# Exclude files with the
$excludedExtensions = @(".sh", ".xlsx", ".txt")
$excludedKeyword = "linux"

$validatedExtensions = @(".ps1", ".psm1", ".psd1")

Write-Host "🚀 Start build for Windows in '$destination'" -ForegroundColor Cyan

# Reset the build folder if it already exists
if (Test-Path $destination) {
    Remove-Item -Recurse -Force $destination
}
New-Item -ItemType Directory -Path $destination | Out-Null

# Get all files from the src directory (excluding .sh files and files containing 'macos' in the name)
$allFiles = Get-ChildItem -Path $sourceRoot -Recurse -File | Where-Object {
    ($excludedExtensions -notcontains $_.Extension) -and ($_.FullName.ToLower() -notlike "*$excludedKeyword*")
}

$totalFiles = $allFiles.Count
$counter = 0
$allErrors = @{}

$filesToValidate = $allFiles | Where-Object { $validatedExtensions -contains $_.Extension }
$totalValidateFiles = $filesToValidate.Count

foreach ($item in $filesToValidate) {
    $script = Get-Content -Path $item.FullName -Raw
    $errors = $null
    [System.Management.Automation.PSParser]::Tokenize($script, [ref]$errors) | Out-Null

    if ($errors) {
        $allErrors.Add($item.FullName, $errors)
    }

    $counter++
    Write-Progress -Id 1 -Activity "Validating common and windows files" -Status "$counter of $totalValidateFiles" -PercentComplete (($counter / $totalValidateFiles) * 100)
}

Write-Progress -Id 1 -Activity "Validation common and windows files completed" -Completed

if ($allErrors.Count -gt 0) {
    # If there are errors, display them
    Write-Host "❌  Build for Windows completed with errors" -ForegroundColor Red
    $allErrors.GetEnumerator() | ForEach-Object {
        Write-Host " => File: " -ForegroundColor Blue -NoNewline
        Write-Host $_.Key 
        $_.Value | ForEach-Object {
            Write-Host "`tLine: " -NoNewline 
            Write-Host $_.Token.StartLine -NoNewline -ForegroundColor Yellow
            Write-Host ", Error: " -NoNewline
            Write-Host $_.Message -ForegroundColor Red
        }
        Write-Host
    }
}
else
{
    $message = ""
    $counter = 0;
    foreach ($item in $allFiles) {
        # Determine the target path based on the source path
        $relativePath = $item.FullName -replace ".*\\$sourceRoot\\", ""
        $target = Join-Path $destination $relativePath
        $targetDir = Split-Path -Path $target -Parent

        if (-Not (Test-Path $targetDir)) {
            New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
        }
        
        $message += " => Copied file: $relativePath`n"
        Copy-Item -Path $item.FullName -Destination $target -Force

        $counter++
        Write-Progress -Id 2 -Activity "Copying common and windows files" -Status "$counter of $totalFiles" -PercentComplete (($counter / $totalFiles) * 100)
    }

    Write-Progress -Id 2 -Activity "Copy common and windows files completed" -Completed

    Write-Host "✅  Build for Windows completed in '$destination' with the following files" -ForegroundColor Green
    Write-Host $message
}


