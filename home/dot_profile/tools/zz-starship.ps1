#starship
Invoke-Expression (starship completions power-shell | Out-String)

function Invoke-Starship-TransientFunction {
    & starship module character
}

Invoke-Expression (starship init powershell | Out-String)
Enable-TransientPrompt
