"$([System.IO.Path]::GetTempPath())\BootstraPS.psm1" |
    % {
        Invoke-WebRequest https://raw.githubusercontent.com/alx9r/BootstraPS/4e2a6a8d0e1b615f9d2f4689f3dcc3f605f4d388/BootstraPS.psm1 -OutFile $_ |
            Out-Null
        $_
        Remove-Item $_
    } |
    % {
        Get-FileHash $_ -Algorithm SHA512 |
            ? {$_.Hash -ne 'AB2DD2E54C7E89186F9FAC612B0CFF4D81F16BB65BEEEA648C0F08925B3D91AD12513A8D40C417F0D4C6F596BEC6FD781A338C75BC2769E0F6F9734FC6B8533A' } | 
            % { throw 'Failed hash check.' }
        $_ | Import-Module
    }
