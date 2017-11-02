"$([System.IO.Path]::GetTempPath())\BootstraPS.psm1" |
    % {
        Invoke-WebRequest https://raw.githubusercontent.com/alx9r/BootstraPS/bca83e2080af10d9079372e268f569082cc502dc/BootstraPS.psm1 -OutFile $_ |
            Out-Null
        $_
        Remove-Item $_
    } |
    % {
        Get-FileHash $_ -Algorithm SHA512 |
            ? {$_.Hash -ne 'D21EC091BC9AB574D1B40ED03E6332B895BCA2F40E8132D9BAE7EB7F3B641329973D6556E2A4F7BB1FD0D7B1B1BA5465E391F2FE45EEE4E213095FF7291A4B07' } | 
            % { throw 'Failed hash check.' }
        $_ | Import-Module
    }
