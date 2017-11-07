"$([System.IO.Path]::GetTempPath())\BootstraPS.psm1" |
    % {
        Invoke-WebRequest https://raw.githubusercontent.com/alx9r/BootstraPS/51e094d8c4479207971de5931ea29266c3f2a0b7/BootstraPS.psm1 -OutFile $_ |
            Out-Null
        $_
        Remove-Item $_
    } |
    % {
        Get-FileHash $_ -Algorithm SHA512 |
            ? {$_.Hash -ne 'AB02BC501CFEE7E9D315DD62695848ECEDA7DCD7789FF0D6E75F1698F14FFA5BA3A57453DC76C3CEE45E070F0CFDB3B442ABEA43D6E2582B20BBF36464FF8073' } |
            % { throw 'Failed hash check.' }
        $_ | Import-Module
    }
