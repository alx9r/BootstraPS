"$([System.IO.Path]::GetTempPath())\BootstraPS.psm1" |
    % {
        Invoke-WebRequest https://raw.githubusercontent.com/alx9r/BootstraPS/0c1ccb16be3335b7cb5094c2101156348bd7def2/BootstraPS.psm1 -OutFile $_ |
            Out-Null
        $_
        Remove-Item $_
    } |
    % {
        Get-FileHash $_ -Algorithm SHA512 |
            ? {$_.Hash -ne '2EA77D4FF980980D09059D105F3A1B8B97147D69E9C256321ABE555A36D8E338D3ACD1DC2BFCF3320535B781F0F0FBF10405F9D97798A01A4244BAA7675CF595' } |
            % { throw 'Failed hash check.' }
        $_ | Import-Module
    }
