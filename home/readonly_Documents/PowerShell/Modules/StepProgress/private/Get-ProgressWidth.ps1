function Get-ProgressWidth {
    [CmdletBinding()]
    [OutputType([int])]
    param()

    $fallback = 80
    try {
        $width = [int]$Host.UI.RawUI.WindowSize.Width
    }
    catch {
        return $fallback
    }

    # Hosts without a console report 0, and a very narrow window leaves no room for the bar
    if ($width -lt 20) { return $fallback }

    $width
}
