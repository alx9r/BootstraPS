"$([System.IO.Path]::GetTempPath())\BootstraPS.psm1" |
    % {
        Invoke-WebRequest https://raw.githubusercontent.com/alx9r/BootstraPS/1d0bdb3622526b7978e5b5e6a16cd943b44631df/BootstraPS.psm1 -OutFile $_ |
            Out-Null
        $_
        Remove-Item $_
    } |
    % {
        Get-FileHash $_ -Algorithm SHA512 |
            ? {$_.Hash -ne '17ADA31F75110CC1A9440D404595424E7A50FB0C6D88F35613766886897047288399DA10688E662C7D6031758A360D80A0ABF83E9F53F4B9873BE6F3E81F3A90' } | 
            % { throw 'Failed hash check.' }
        $_ | Import-Module
    }
