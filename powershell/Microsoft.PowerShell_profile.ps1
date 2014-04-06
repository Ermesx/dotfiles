$myProfile = Join-Path (Split-Path $profile) profile_common.ps1
if (Test-Path $myProfile) {
. $myProfile
}
Remove-Item variable:myProfile
