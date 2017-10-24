"$([System.IO.Path]::GetTempPath())\BootstraPS.psm1" |
    % {
        Invoke-WebRequest https://raw.githubusercontent.com/alx9r/BootstraPS/14b43953c2dfb71ad218f8b099c457c9268c03d3/BootstraPS.psm1 -OutFile $_ |
            Out-Null
        $_
        Remove-Item $_
    } |
    % {
        Get-FileHash $_ -Algorithm SHA512 |
            ? {$_.Hash -ne 'A7C324A0B7B969AA622431431DCB995AE767B1D28762C1E08AF515725961B40EF23A8B1BC37886E700AD07CBD22EE15AB9550892FD5A0458DEF1ED4E82C4B8C6' } | 
            % { throw 'Failed hash check.' }
        $_ | Import-Module
    }
