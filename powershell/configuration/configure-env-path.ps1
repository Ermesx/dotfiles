function Test-Env ($path)
{
	return $env:path -split ";" -contains $path
}

function Get-FolderInProgramFiles() {
    param ( [string]$folder = $(throw "Please secify searched folder within program files"))

    return ls env: | ? Name -match ^ProgramFiles | ForEach-Object { join-path $_.Value $folder } | Where-Object { Test-Path $_ }
}

$profilePath = split-path $PROFILE

if (!(Test-Env "$profilePath\Scripts")) { $env:PATH += ";$profilePath\Scripts"; write-host "Add to PATH: $profilePath\Scripts" }

$gitPath = (Get-FolderInProgramFiles "Git")
if ($gitPath)
{
	if (!(Test-Env "$gitPath\minigw\bin")) { $env:PATH += ";$gitPath\minigw\bin"; write-host "Add to PATH: $gitPath\minigw\bin" }
	if (!(Test-Env "$gitPath\bin")) { $env:PATH += ";$gitPath\bin"; write-host "Add to PATH: $gitPath\bin" }
	if (!(Test-Env "$gitPath\cmd")) { $env:PATH += ";$gitPath\cmd"; write-host "Add to PATH: $gitPath\cmd" }	
}
else { write-host "There is not Git in ProgramFiles. Please install" -ForegroundColor Red }
