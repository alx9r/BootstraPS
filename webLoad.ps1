"$([System.IO.Path]::GetTempPath())\BootstraPS.psm1" |
    % {
        Invoke-WebRequest https://raw.githubusercontent.com/alx9r/BootstraPS/77c848b86a3e037b1b998cc9e8ec855cdadb9ac8/BootstraPS.psm1 -OutFile $_ |
            Out-Null
        $_
        Remove-Item $_
    } |
    % {
        Get-FileHash $_ -Algorithm SHA512 |
            ? {$_.Hash -ne '69543475C9124C6112E4998CADF1286D7CD5F77FC5674FBA7DDBD4C8496321BA0B805FAC76C06B3E0D52326BBC152CAEA3C52DECAEA90DFBC98576C3C599D59E' } | 
            % { throw 'Failed hash check.' }
        $_ | Import-Module
    }
