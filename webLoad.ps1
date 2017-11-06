"$([System.IO.Path]::GetTempPath())\BootstraPS.psm1" |
    % {
        Invoke-WebRequest https://raw.githubusercontent.com/alx9r/BootstraPS/8315282a987fc3fc2e647605612e7d8135435048/BootstraPS.psm1 -OutFile $_ |
            Out-Null
        $_
        Remove-Item $_
    } |
    % {
        Get-FileHash $_ -Algorithm SHA512 |
            ? {$_.Hash -ne 'FFCBF7D37D25DCA10D36FE1E83A8A5FA269F0B59E2A1623CEEC91F47F5DD68B6C50EA18CD9C25DAAF4E91D4C9872B5DC91719C934B8B8054B02C8C6B65C4DD62' } | 
            % { throw 'Failed hash check.' }
        $_ | Import-Module
    }
