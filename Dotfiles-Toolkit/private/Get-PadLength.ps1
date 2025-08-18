function Get-PadLength {
    param (
        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Text
    )
    
    return " " * (32 - $Text.Length)
}