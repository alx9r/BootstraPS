"$([System.IO.Path]::GetTempPath())\BootstraPS.psm1" |
    % {
        Invoke-WebRequest https://raw.githubusercontent.com/alx9r/BootstraPS/dbc7350d9e181ad7b8e5b66c42fed9d6cf54c5e6/BootstraPS.psm1 -OutFile $_ |
            Out-Null
        $_
        Remove-Item $_
    } |
    % {
        Get-FileHash $_ -Algorithm SHA512 |
            ? {$_.Hash -ne '0D1AE2EEA2F7AF8C2EF6733FF4A952683F3DC2A44F6122BFA8E8C10AC4AE1446B714FD23B32B5B1F34368CE9B7A35CC90E50474E3C641EDAEFAD659BA8702243' } | 
            % { throw 'Failed hash check.' }
        $_ | Import-Module
    }
