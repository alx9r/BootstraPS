"$([System.IO.Path]::GetTempPath())\BootstraPS.psm1" |
    % {
        Invoke-WebRequest https://raw.githubusercontent.com/alx9r/BootstraPS/1836149fb65315751c7c32b62f3a80205558d4dc/BootstraPS.psm1 -OutFile $_ |
            Out-Null
        $_
        Remove-Item $_
    } |
    % {
        Get-FileHash $_ -Algorithm SHA512 |
            ? {$_.Hash -ne 'F40BD13C59353C3C70A25694F9DC8D0EF0828613E914D32A9FF544E7580D3B733AB5D663F3A4908C9C3E194E47D21BAE556EF1EC89EF0A2B13E39C3DFC876B78' } | 
            % { throw 'Failed hash check.' }
        $_ | Import-Module
    }
