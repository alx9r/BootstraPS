"$([System.IO.Path]::GetTempPath())\BootstraPS.psm1" |
    % {
        Invoke-WebRequest https://raw.githubusercontent.com/alx9r/BootstraPS/25aa270352c2cd763e842b9439803cd06141341e/BootstraPS.psm1 -OutFile $_ |
            Out-Null
        $_
        Remove-Item $_
    } |
    % {
        Get-FileHash $_ -Algorithm SHA512 |
            ? {$_.Hash -ne 'E9526FE08759EBA12D4E5BE95263E09ABABC7F12856F4C7E5018803AF98B171D4248A3C64D2434E785CEEC6A0339899AAA6C3BF20C1B7E6C47F2616932033686' } |
            % { throw 'Failed hash check.' }
        $_ | Import-Module
    }
