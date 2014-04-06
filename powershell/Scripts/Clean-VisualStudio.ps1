param(
  $path= $(throw "Path is required.")
)
    $fullpath = (Get-Item $path).FullName
    write-host "Cleaning bin from: $fullpath"
    get-childitem $fullpath -include bin -recurse | remove-item

    write-host "Cleaning obj from: $fullpath"
    get-childitem $fullpath -include obj -recurse | remove-item
