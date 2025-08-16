function Update-KeyBinding
{
<#
.SYNOPSIS
Updates a key binding for a function in PSReadLine.

.DESCRIPTION
The `Update-KeyBinding` function assigns a key to a selected function in PSReadLine.
The old key binding must be specified and will be removed when the new binding is created.

.PARAMETER Key
The key to be assigned to the function. Required.

.PARAMETER OldKey
The key whose binding should be removed. Required.

.PARAMETER Function
The name of the function to assign to the key. Optional — if not provided, the function from the old binding will be used.

.EXAMPLE
Update-KeyBinding -Key "Ctrl+K" -OldKey "Ctrl+J" -Function "UpHistory"

Assigns the `Ctrl+K` key to the `UpHistory` function and removes the old binding for `Ctrl+J`.

.EXAMPLE
Update-KeyBinding -Key "Ctrl+L" -OldKey "Ctrl+K"

Assigns the `Ctrl+L` key to the same function that was bound to `Ctrl+K` and removes the old binding for `Ctrl+K`.

#>

    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]$Key,

        [Parameter(Mandatory)]
        [string]$OldKey,

        [string]$Function
    )
    
    $oldBinding = (Get-PSReadLineKeyHandler | Where-Object { $_.Key -eq $OldKey })
    if (-not $oldBinding) {
        throw "❌ No key binding found for '$OldKey'. Please provide a valid key to replace."
    }

    if (-not $Function) {
        $Function = $oldBinding.Function
    }

    Write-Verbose "🔧 Assigning key $Key to function '$Function'"
    Set-PSReadLineKeyHandler -Key $Key -Function $Function

    Write-Verbose "❌ Removing old key binding: $OldKey"
    Remove-PSReadLineKeyHandler -Key $OldKey
}