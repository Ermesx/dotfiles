param(
  $cmd= $(throw "Add command to find")
)

gcm -ErrorAction "SilentlyContinue" $cmd | ft Definition
