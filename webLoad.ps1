[System.IO.Path]::GetTempFileName() |
    % {
        Invoke-WebRequest https://raw.githubusercontent.com/alx9r/BootstraPS/28cbeb78ea2e478889717e741dc12fdceb68ab48/BootstraPS.ps1 -OutFile $_ |
            Out-Null
        $_
        Remove-Item $_
    } |
    % {
        Get-FileHash $_ -Algorithm SHA512 |
            ? {$_.Hash -ne 'E6302F8FA5AD329DFAE397584630441B0B8AF5D1547CD62BE895BBDFD8EB6A3379C863CD95722C8FD03DF75117FB56A810125CA89E2AACFA7756919C0AD354AA' } | 
            % { throw 'Failed hash check.' }
        $_ | Get-Item | Get-Content -Raw | Invoke-Expression
    }
