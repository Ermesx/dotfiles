function Update-ScriptBlock {
<#
.SYNOPSIS
    Creates a new script block by replacing placeholders with actual values.

.DESCRIPTION
    This function takes a script block template containing placeholders in the format {{key}} 
    and replaces them with corresponding values from a hashtable. It validates the resulting 
    script block for syntax errors before returning it.

.PARAMETER ScriptBlockTemplate
    The template script block containing placeholders to be replaced. Placeholders should 
    be in the format {{key}} where 'key' corresponds to a key in the Values hashtable.

.PARAMETER Values
    A hashtable containing key-value pairs where keys match the placeholder names 
    (without the curly braces) and values are the replacement strings.

.OUTPUTS
    System.Management.Automation.ScriptBlock
    Returns a new script block with all placeholders replaced by their corresponding values.

.THROWS
    System.Exception
    Throws an exception if the resulting script block contains syntax errors, 
    including line numbers and error messages.

.EXAMPLE
    $template = { Write-Host "Hello {{name}}, you are {{age}} years old" }
    $values = @{ name = "John"; age = "25" }
    $result = Update-ScriptBlock -ScriptBlockTemplate $template -Values $values
    # Returns: { Write-Host "Hello John, you are 25 years old" }

.EXAMPLE
    $template = { Get-Process {{processName}} | Stop-Process -Force }
    $values = @{ processName = "notepad" }
    $result = Update-ScriptBlock -ScriptBlockTemplate $template -Values $values
    # Returns: { Get-Process notepad | Stop-Process -Force }    
#>
    [CmdletBinding()]
    [OutputType([ScriptBlock])]
    param (
        [Parameter(Mandatory = $true)]
        [ScriptBlock]$ScriptBlockTemplate,
        [Parameter(Mandatory = $true)]
        [hashtable]$Values
    )
    
    # Replace placeholders with actual values
    $stringBuilder = New-Object System.Text.StringBuilder($ScriptBlockTemplate.ToString())
    $Values.Keys | ForEach-Object { [void]$stringBuilder.Replace("{{$_}}", $Values[$_]) }
    $script = $stringBuilder.ToString()

    # Check if the script block is valid
    $errors = $null
    [System.Management.Automation.PSParser]::Tokenize($script, [ref]$errors) | Out-Null
    
    if ($errors) {
        $errorMessages = $errors | ForEach-Object { "Line $( $_.Line): $( $_.Message )" }
        $combinedMessage = "❌ Error in script block:`n" + ($errorMessages -join "`n")
                
        throw $combinedMessage
    }
        
    return [ScriptBlock]::Create($script)
}