"$([System.IO.Path]::GetTempPath())\BootstraPS.psm1" |
    % {
        Invoke-WebRequest https://raw.githubusercontent.com/alx9r/BootstraPS/53e33bf591bdcd30d6aaf3a2efee1f7ebd04509f/BootstraPS.psm1 -OutFile $_ |
            Out-Null
        $_
        Remove-Item $_
    } |
    % {
        Get-FileHash $_ -Algorithm SHA512 |
            ? {$_.Hash -ne '56F8EF6194D43121BC6D98F49FA7A6AE0A123322ABC3277B4E6ECCB316FCFDB11546A9A4F461B737B22EBEB9A0D2114EE22E53F69F32E6629DC728DC00FCEDCB' } | 
            % { throw 'Failed hash check.' }
        $_ | Import-Module
    }
