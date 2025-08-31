# Initializes fd completion
Invoke-Expression (& { (fd --gen-completions powershell | out-string) })
