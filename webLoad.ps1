[System.IO.Path]::GetTempFileName() |
    % {
        Invoke-WebRequest https://raw.githubusercontent.com/alx9r/BootstraPS/4a4d054aa0538e690d4c4fcbd00058f3dcba6faf/BootstraPS.psm1 -OutFile $_ |
            Out-Null
        $_
        Remove-Item $_
    } |
    % {
        Get-FileHash $_ -Algorithm SHA512 |
            ? {$_.Hash -ne '0E1761EF71FE4CF6B7524CF9A66CE9567E39EF6D4447AC4442575F7F9EFBF4431DC6EEE5F9719A29B8A3D0218F313738D84146E04AF740878DE5C20CFCA0F0A2' } | 
            % { throw 'Failed hash check.' }
        $_ | Get-Item | Get-Content -Raw | Invoke-Expression
    }
