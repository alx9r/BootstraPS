"$([System.IO.Path]::GetTempPath())\BootstraPS.psm1" |
    % {
        Invoke-WebRequest https://raw.githubusercontent.com/alx9r/BootstraPS/69e8f877bb7c9f1db566026cfc618d8e99fb1e76/BootstraPS.psm1 -OutFile $_ |
            Out-Null
        $_
        Remove-Item $_
    } |
    % {
        Get-FileHash $_ -Algorithm SHA512 |
            ? {$_.Hash -ne '3B624810538A82EDBA8013F3D21990D61267C1580A5B944ECBB8BCEAEFBC9E40D265541F4B8186651873BC7FD93658A310DC7D5DA4C98EA81E8D86229B4038C3' } |
            % { throw 'Failed hash check.' }
        $_ | Import-Module
    }
