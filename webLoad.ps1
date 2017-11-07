"$([System.IO.Path]::GetTempPath())\BootstraPS.psm1" |
    % {
        Invoke-WebRequest https://raw.githubusercontent.com/alx9r/BootstraPS/e9bbfb8d1a1311f883e9a418b68643aae4c00048/BootstraPS.psm1 -OutFile $_ |
            Out-Null
        $_
        Remove-Item $_
    } |
    % {
        Get-FileHash $_ -Algorithm SHA512 |
            ? {$_.Hash -ne 'AEED9253E1C49B1AFBFAD209ED94C08EE25EBFBDF77D21C9835025D1A93E6A980BE82BBE721188F4824E4FF28688F67F4B30D9EF57D6BAB336EDD50CDF7112D8' } |
            % { throw 'Failed hash check.' }
        $_ | Import-Module
    }
