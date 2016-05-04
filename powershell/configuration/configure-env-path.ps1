function Test-Env ($path)
{
	return $env:path -split ";" -contains $path
}

function Get-FolderInProgramFiles() {
    param ( [string]$folder = $(throw "Please secify searched folder within program files"))

    return ls env: | ? Name -match ^ProgramFiles | ForEach-Object { join-path $_.Value $folder } | Where-Object { Test-Path $_ }
}

function Set-To-Env-Path($path)
{
	if (!(Test-Env $path)) { $env:PATH += ";$path"; write-host "Add to PATH: $path" }
}

$profilePath = split-path $PROFILE
Set-To-Env-Path "$profilePath\Scripts"

#12.0 because I have VS 2013
#-1 because MSbuild exists in both directories and I want to get x86(last directory)
$msbuildPath = (Get-FolderInProgramFiles "MSBuild")[-1]
Set-To-Env-Path "$msbuildPath\12.0\Bin"

$gitPath = (Get-FolderInProgramFiles "Git")
if ($gitPath)
{
	Set-To-Env-Path "$gitPath\minigw\bin"
	Set-To-Env-Path "$gitPath\bin" 
	Set-To-Env-Path "$gitPath\cmd"
	Set-To-Env-Path "$gitPath\usr\bin" 
}
else { write-host "There is not Git in ProgramFiles. Please install" -ForegroundColor Red }

Set-To-Env-Path "$env:LOCALAPPDATA\Microsoft\dotnet"