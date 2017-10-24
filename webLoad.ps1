"$([System.IO.Path]::GetTempPath())\BootstraPS.psm1" |
    % {
        Invoke-WebRequest https://raw.githubusercontent.com/alx9r/BootstraPS/fd5119e9433a172609e6ba85f67e242ad59d38ab/BootstraPS.psm1 -OutFile $_ |
            Out-Null
        $_
        Remove-Item $_
    } |
    % {
        Get-FileHash $_ -Algorithm SHA512 |
            ? {$_.Hash -ne '5601C3DA2AC205390411ED2E9C8917EEEBBA59E0ACD2C27E65C1D44F8389EEA838E39D2613702EFF7E3E1D5F22CD4CE9ECFBEA33F145FF38BAD6F2C1842CB189' } | 
            % { throw 'Failed hash check.' }
        $_ | Import-Module
    }
