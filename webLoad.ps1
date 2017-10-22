"$([System.IO.Path]::GetTempPath())\BootstraPS.psm1" |
    % {
        Invoke-WebRequest https://raw.githubusercontent.com/alx9r/BootstraPS/5122c0ac224ca38987a013c412900f03fb958b0b/BootstraPS.psm1 -OutFile $_ |
            Out-Null
        $_
        Remove-Item $_
    } |
    % {
        Get-FileHash $_ -Algorithm SHA512 |
            ? {$_.Hash -ne 'B7E81719D7E576E2D53B35B89A33245E6CC52EBDCBB79447C64BCB55E8235BF0A7B6F8F615F82DD6BE5C60C9B155C55F1A06F606FB8D36CF76A4515E81BF13D9' } | 
            % { throw 'Failed hash check.' }
        $_ | Import-Module
    }
