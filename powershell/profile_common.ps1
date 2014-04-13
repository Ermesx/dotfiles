# Local functions
function Test-InPath($fileName){
    $found = $false
    Find-InPath $fileName | %{$found = $true}

    return $found
}

function Find-InPath($fileName){
    $env:PATH.Split(';') | ?{!([System.String]::IsNullOrEmpty($_))} | %{
        if(Test-Path $_){
            ls $_ | ?{ $_.Name -like $fileName }
        }
    }
}

# General variables
$computer    = get-content env:computername
$profileRoot = "$(split-path $profile)"
$scripts     = "$profileRoot\Scripts"
$modules     = "$profileRoot\Modules"

# Include common functions
. $scripts\common-utils.ps1

$env:path += ";$profileRoot;$scripts"

# Configurations based on computername
switch($computer)
{
	{ "PC06244", "PC06639" -contains $_ }
		{
			$env:http_proxy = "http://proxy:8080";
			$env:https_proxy = "http://proxy:8080";
			break;
		}
}

set-alias ai assembly-info

# Configuring git
$gitInstallDir = Get-FolderInProgramFiles "Git"
if ($gitInstallDir -ne $null) {
    #$env:Path = "$env:Path;$gitInstallDir\bin;$gitInstallDir\mingw\bin"
	#$env:Path = "$env:Path;$gitInstallDir\mingw\bin"
    if(!$Env:HOME) { $env:HOME = "$env:HOMEDRIVE$env:HOMEPATH" }
    if(!$Env:HOME) { $env:HOME = $env:USERPROFILE }
    if(!$Env:GIT_HOME) { $env:GIT_HOME = "$gitInstallDir" }
    $env:PLINK_PROTOCOL = 'ssh'
}

# Import PowerTab
Import-Module "PowerTab" -ArgumentList "C:\repositories\dotfiles\powershell\PowerTabConfig.xml"

# Run posh-git init script
pushd
cd $modules\posh-git
# Load posh-git module from current directory
Import-Module .\posh-git
Enable-GitColors
popd

# Run posh-rake init script
#pushd
#cd $modules\posh-rake
# Load posh-rake module from current directory
#Import-Module .\posh-rake
#popd

# Configure prompt
. $profileRoot\configurePrompt.ps1

# Configure ssh-agent so git doesn't require a password on every push
if(Test-InPath ssh-agent.*){
    . $scripts\ssh-agent-utils.ps1
}else{
    Write-Error "ssh-agent cannot be found in your PATH, please add it"
}


# Environment for git 
$env:TERM = 'cygwin'
$env:LESS = 'FRSX'


function Get-Batchfile ($file) {
    $cmd = "`"$file`" & set"
    cmd /c $cmd | Foreach-Object {
        $p, $v = $_.split('=')
        Set-Item -path env:$p -value $v
    }
}

function Enable-VisualStudio($version = "11.0") {
    if ([intptr]::size -eq 8) {
        $key = "HKLM:SOFTWARE\Wow6432Node\Microsoft\VisualStudio\" + $version
    }
    else {
        $key = "HKLM:SOFTWARE\Microsoft\VisualStudio\" + $version
    }

    $VsKey = Get-ItemProperty $key
    if ($VsKey) {
        $VsInstallPath = [System.IO.Path]::GetDirectoryName($VsKey.InstallDir)
        $VsToolsDir = [System.IO.Path]::GetDirectoryName($VsInstallPath)
        $VsToolsDir = [System.IO.Path]::Combine($VsToolsDir, "Tools")
        $BatchFile = [System.IO.Path]::Combine($VsToolsDir, "vsvars32.bat")
        
        Get-Batchfile $BatchFile
        
        [System.Console]::Title = "Visual Studio " + $version + " Windows Powershell"
        
        $iconPath = Join-Path $profile "vspowershell.ico"
        Set-ConsoleIcon $iconPath
    }
    else {
        Write-Host "Visual Studio $version is not installed."
    }
}

# launch VS dev webserver, from Harry Pierson
# http://devhawk.net/2008/03/20/WebDevWebServer+PowerShell+Function.aspx
function webdev($path,$port=8080,$vpath='/') {
    $spath = "$env:ProgramFiles\Common*\microsoft*\DevServer\10.0\WebDev.WebServer40.EXE"

    $spath = resolve-path $spath
    $rpath = resolve-path $path
    &$spath "/path:$rpath" "/port:$port" "/vpath:$vpath"
    "Started WebDev Server for '$path' directory on port $port"
}

# uuidgen.exe replacement
function uuidgen {
   [guid]::NewGuid().ToString('d')
}

# return all IP addresses
function get-ips() {
   $ent = [net.dns]::GetHostEntry([net.dns]::GetHostName())
   return $ent.AddressList | ?{ $_.ScopeId -ne 0 } | %{
      [string]$_
   }
}

# save last 100 history items on exit
$historyPath = Join-Path (split-path $profile) history.clixml
 
# hook powershell's exiting event & hide the registration with -supportevent.
Register-EngineEvent -SourceIdentifier powershell.exiting -SupportEvent -Action {
    Get-History -Count 20 | Export-Clixml (Join-Path (split-path $profile) history.clixml) }
 
# load previous history, if it exists
if ((Test-Path $historyPath)) {
    Import-Clixml $historyPath | ? {$count++;$true} | Add-History
    Write-Host -Fore Green "`nLoaded $count history item(s).`n"
}


Set-Alias vs Enable-VisualStudio

# Posh-Hg and Posh-git prompt

#. $profileRoot\Modules\posh-hg\profile.example.ps1
#. $profileRoot\Modules\posh-git\profile.example.ps1


. $profileRoot\Scripts\Set-ConsoleIcon.ps1

# creating a function since set-alias can't pass piped parameters
function aia {
    get-childitem | ?{ $_.extension -eq ".dll" } | %{ ai $_ }
}

function dc {
    git diff | out-colordiff
}

remove-item alias:ls
set-alias ls Get-ChildItemColor

function Get-ChildItemColor {
    $fore = $Host.UI.RawUI.ForegroundColor

    Invoke-Expression ("Get-ChildItem $args") |
    %{
      if ($_.GetType().Name -eq 'DirectoryInfo') {
        $Host.UI.RawUI.ForegroundColor = 'White'
        echo $_
        $Host.UI.RawUI.ForegroundColor = $fore
      } elseif ($_.Name -match '\.(zip|tar|gz|rar)$') {
        $Host.UI.RawUI.ForegroundColor = 'Blue'
        echo $_
        $Host.UI.RawUI.ForegroundColor = $fore
      } elseif ($_.Name -match '\.(exe|bat|cmd|py|pl|ps1|psm1|vbs|rb|reg)$') {
        $Host.UI.RawUI.ForegroundColor = 'Green'
        echo $_
        $Host.UI.RawUI.ForegroundColor = $fore
      } elseif ($_.Name -match '\.(txt|cfg|conf|ini|csv|sql|xml|config)$') {
        $Host.UI.RawUI.ForegroundColor = 'Cyan'
        echo $_
        $Host.UI.RawUI.ForegroundColor = $fore
      } elseif ($_.Name -match '\.(cs|asax|aspx.cs)$') {
        $Host.UI.RawUI.ForegroundColor = 'Yellow'
        echo $_
        $Host.UI.RawUI.ForegroundColor = $fore
       } elseif ($_.Name -match '\.(aspx|spark|master)$') {
        $Host.UI.RawUI.ForegroundColor = 'DarkYellow'
        echo $_
        $Host.UI.RawUI.ForegroundColor = $fore
       } elseif ($_.Name -match '\.(sln|csproj)$') {
        $Host.UI.RawUI.ForegroundColor = 'Magenta'
        echo $_
        $Host.UI.RawUI.ForegroundColor = $fore
       }
        else {
        $Host.UI.RawUI.ForegroundColor = $fore
        echo $_
      }
    }
}

# Use VS to either open the passed solution or the first (only) solution in the
# current directory.
function vsh {
    param ($param)

    if ($param -eq $NULL) {
        "A solution was not specified, opening the first one found."
        $solutions = get-childitem | ?{ $_.extension -eq ".sln" }
    }
    else {
        "Opening {0} ..." -f $param
        vs $param
        break
    }
    if ($solutions.count -gt 1) {
        "Opening {0} ..." -f $solutions[0].Name
        vs $solutions[0].Name
    }
    else {
        "Opening {0} ..." -f $solutions.Name
        vs $solutions.Name
    }
}

function set-ent-ram {
    $Env:CustomBeforeMicrosoftCommonTargets="R:\Projects\Enterprise\Before.Microsoft.Common.targets"
    $Env:GIT_DIR="C:\Projects\Enterprise\.git"
}


[GC]::Collect()
