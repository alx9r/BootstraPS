. "$PSScriptRoot\helpers.ps1"

@(
    @{ f = "$PSScriptRoot\webLoad.ps1"; s = {New-WebloadPs1} }
    @{ f = "$PSScriptRoot\readme.md";   s = {New-ReadmeMd} }
) |
% {
    $f = $_.f; $s = & $_.s;
    $s |
        Out-String |
        % { $_ -replace "`r`n","`n" } |
        % { [System.IO.File]::WriteAllText($f,$_) }
}
