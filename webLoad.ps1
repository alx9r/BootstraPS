"$([System.IO.Path]::GetTempPath())\BootstraPS.psm1" |
    % {
        Invoke-WebRequest https://raw.githubusercontent.com/alx9r/BootstraPS/a331c0aedb8db4cddd9ced4637e986c4984e8d23/BootstraPS.psm1 -OutFile $_ |
            Out-Null
        $_
        Remove-Item $_
    } |
    % {
        Get-FileHash $_ -Algorithm SHA512 |
            ? {$_.Hash -ne '9A1AE2FDB5E602312FCDB006AE95CAB383A92BE91D7F1596945227D0FB8E1E7A6C35307B8F5436416EB2F5EA13192FAC363599974FA97D81AE07264F2767E276' } | 
            % { throw 'Failed hash check.' }
        $_ | Import-Module
    }
