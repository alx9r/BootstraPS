"$([System.IO.Path]::GetTempPath())\BootstraPS.psm1" |
    % {
        Invoke-WebRequest https://raw.githubusercontent.com/alx9r/BootstraPS/08a5d3cb97b5dfdeeab76de514d55467249b3cc4/BootstraPS.psm1 -OutFile $_ |
            Out-Null
        $_
        Remove-Item $_
    } |
    % {
        Get-FileHash $_ -Algorithm SHA512 |
            ? {$_.Hash -ne 'D8BB92FBDAD0D103E5B2A7720538919E933B9C06B528F946702D9677342C3D49DC3A50585C6556060D45756E59298F1B6C6B84C212A66F3BBD4968D5B0767C3A' } | 
            % { throw 'Failed hash check.' }
        $_ | Import-Module
    }
