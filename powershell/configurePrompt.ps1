$global:GitPromptSettings.BeforeText = ' [git: '

function isCurrentDirectoryARepository($type) {

    if ((Test-Path $type) -eq $TRUE) {
        return $TRUE
    }

    # Test within parent dirs
    $checkIn = (Get-Item .).parent
    while ($checkIn -ne $NULL) {
        $pathToTest = $checkIn.fullname + '/' + $type;
        if ((Test-Path $pathToTest) -eq $TRUE) {
            return $TRUE
        } else {
            $checkIn = $checkIn.parent
        }
    }
    return $FALSE
}

# Set up a simple prompt, adding the git prompt parts inside git repos
function prompt {
	 $realLASTEXITCODE = $LASTEXITCODE

    # Reset color, which can be messed up by Enable-GitColors
    $Host.UI.RawUI.ForegroundColor = $GitPromptSettings.DefaultForegroundColor

    # Cut long path
    $m = 25 # maximum prompt length
    $str = $pwd.Path
    if ($str.length -ge $m)
    {
        # The prompt will begin with "...",
        # end with ">", and in between contain
        # as many of the path characters as will fit,
        # reading from the end of the path.
        $str = "..." + $str.substring($str.length - $m + 4)
    }

    Write-Host($str) -ForegroundColor DarkGray -nonewline

    Write-VcsStatus

    $global:LASTEXITCODE = $realLASTEXITCODE
	
	return '> '
}

function DevTabExpansion($lastBlock){
	switch -regex ($lastBlock) {
		'dev (\S*)$' {
			ls $dev | ?{ $_.Name -match "^$($matches[1])" }
		}
	}
}

if(-not (Test-Path Function:\DefaultTabExpansion)) {
	Rename-Item Function:\TabExpansion DefaultTabExpansion
}

# Set up tab expansion and include git expansion
function TabExpansion($line, $lastWord) {
	$lastBlock = [regex]::Split($line, '[|;]')[-1]

	switch -regex ($lastBlock) {		
		# Development folder tab expansion
		'dev (.*)' { DevTabExpansion $lastBlock }
		# Fall back on existing tab expansion
		default { DefaultTabExpansion $line $lastWord }
	}
}
