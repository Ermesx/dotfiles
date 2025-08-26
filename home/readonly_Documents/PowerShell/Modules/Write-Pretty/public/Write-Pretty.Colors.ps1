# Define global variables for static colors

$Global:Colors = @{
    'Green' = @{ ForegroundColor = '0,255,0'; FallbackForegroundColor = 'Green' }
    'Red' = @{ ForegroundColor = '255,0,0'; FallbackForegroundColor = 'Red' }
    'Yellow' = @{ ForegroundColor = '255,255,0'; FallbackForegroundColor = 'Yellow' }
    'Cyan' = @{ ForegroundColor = '0,255,255';  FallbackForegroundColor = 'Cyan' }
}

# Define function color aliases for Write-Pretty
function Write-Green {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Text,
        [switch]$NoNewLine
    )
    $color = $Global:Colors['Green']
    Write-Pretty -Text $Text @color -NoNewLine:$NoNewLine
}

function Write-Red {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Text,
        [switch]$NoNewLine
    )
    $color = $Global:Colors['Red']
    Write-Pretty -Text $Text @color -NoNewLine:$NoNewLine
}

function Write-Yellow {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Text,
        [switch]$NoNewLine
    )
    $color = $Global:Colors['Yellow']
    Write-Pretty -Text $Text @color -NoNewLine:$NoNewLine
}

function Write-Cyan {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Text,
        [switch]$NoNewLine
    )
    $color = $Global:Colors['Cyan']
    Write-Pretty -Text $Text @color -NoNewLine:$NoNewLine
}