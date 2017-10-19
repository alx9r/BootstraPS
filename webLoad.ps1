"$([System.IO.Path]::GetTempPath())\BootstraPS.psm1" |
    % {
        Invoke-WebRequest https://raw.githubusercontent.com/alx9r/BootstraPS/1836149fb65315751c7c32b62f3a80205558d4dc/BootstraPS.psm1 -OutFile $_ |
            Out-Null
        $_
        Remove-Item $_
    } |
    % {
        Get-FileHash $_ -Algorithm SHA512 |
            ? {$_.Hash -ne '7A3FD5628FF69D43C40262C92D8787A814E5DB57EE102F71DF769E209457F2C42ED2101E2A6A78615902E89382D7B2B1DB3AF4ECA7E5DCC5030928BF5AD0A511' } | 
            % { throw 'Failed hash check.' }
        $_ | Import-Module
    }
