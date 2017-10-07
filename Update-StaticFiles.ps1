. "$PSScriptRoot\helpers.ps1"

New-WebloadPs1 |
    Set-Content "$PSScriptRoot\webLoad.ps1"
New-ReadmeMd |
    Set-Content "$PSScriptRoot\readme.md"