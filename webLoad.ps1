"$([System.IO.Path]::GetTempPath())\BootstraPS.psm1" |
    % {
        Invoke-WebRequest https://raw.githubusercontent.com/alx9r/BootstraPS/76ff5f0c7011cca3c1b13d40985f93b9f4d9db43/BootstraPS.psm1 -OutFile $_ |
            Out-Null
        $_
        Remove-Item $_
    } |
    % {
        Get-FileHash $_ -Algorithm SHA512 |
            ? {$_.Hash -ne 'D839DF13E6601A1505DDB7300499DDE2F998CB675AA33B0031F6ABD69F1662D170F37B5E6CEE4D9D9268F15CFB49384C94184DE02345FF45B0661970CD7B93C9' } | 
            % { throw 'Failed hash check.' }
        $_ | Import-Module
    }
