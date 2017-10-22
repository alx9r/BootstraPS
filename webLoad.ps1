"$([System.IO.Path]::GetTempPath())\BootstraPS.psm1" |
    % {
        Invoke-WebRequest https://raw.githubusercontent.com/alx9r/BootstraPS/9c6fcb1fbef25e7d1d3a34ad134725b88ded8bbf/BootstraPS.psm1 -OutFile $_ |
            Out-Null
        $_
        Remove-Item $_
    } |
    % {
        Get-FileHash $_ -Algorithm SHA512 |
            ? {$_.Hash -ne '254D832DC25261FE44225A35759BA8F897E9F30D49199F2E7D9E8A945B54018DE6F31C5B9AB570093BA2853E4C737465B8DCC6D07637243D905E8C0700C39337' } | 
            % { throw 'Failed hash check.' }
        $_ | Import-Module
    }
