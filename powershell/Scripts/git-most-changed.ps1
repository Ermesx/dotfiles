set-alias git-most-changed mc

function mc ($lines = 25)  {
	 git log --pretty=format: --name-only | sort | uniq -c | sort -Descending | where -FilterScript {$_ -like "*.cs" -or $_ -like "*.cshtml"} | select -First $lines
}
