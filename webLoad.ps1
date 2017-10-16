"$([System.IO.Path]::GetTempPath())\BootstraPS.psm1" |
    % {
        Invoke-WebRequest https://raw.githubusercontent.com/alx9r/BootstraPS/5b771a6795c993a4517dfa08aa75d6c5939f97f6/BootstraPS.psm1 -OutFile $_ |
            Out-Null
        $_
        Remove-Item $_
    } |
    % {
        Get-FileHash $_ -Algorithm SHA512 |
            ? {$_.Hash -ne '66205F91DC16C30845C03486F0EA1E46C3A8807BEA3C0C38CF6A719599EB3547CA4F64888EDC6E07FE77DFA86CFD7DCB8C5A52C65231133D9E949DE4C06C0DEA' } | 
            % { throw 'Failed hash check.' }
        $_ | Import-Module
    }
