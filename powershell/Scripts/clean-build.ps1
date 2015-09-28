param(
  $Path = (pwd),
  [switch]$Recurse,
  [switch]$WhatIf
)
		
	if ((!$Recurse) -And (test-path "bin") -And (test-path "obj"))
	{
		write-host "Cleaning from: $path"
		if ($Whatif)
		{ rm "$path\*" -Include bin, obj -Force -Whatif }
		else
		{ rm "$path\*" -Include bin, obj -Force -Verbose }
	}
	elseif ($Recurse)
	{
		write-host "Cleaning from: " -nonewline
		write-host $path -ForegroundColor Green
		if ($Whatif)
		{ rm "$path\*" -Include bin, obj -Recurse -Force -Whatif }
		else
		{ rm "$path\*" -Include bin, obj -Recurse -Force -Verbose }
	}
	else
	{
		write-host "There are not bin and obj folders try with option" -ForegroundColor Yellow -nonewline
		write-host " -Recurse" -ForegroundColor Red
	}

	
