function Get-PadLength {
    param (
        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Text
    )
    
    return " " * (36 - $Text.Length)
}