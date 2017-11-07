"$([System.IO.Path]::GetTempPath())\BootstraPS.psm1" |
    % {
        Invoke-WebRequest https://raw.githubusercontent.com/alx9r/BootstraPS/e9aa2f3b827b856db4270297f0b96de72594b0fe/BootstraPS.psm1 -OutFile $_ |
            Out-Null
        $_
        Remove-Item $_
    } |
    % {
        Get-FileHash $_ -Algorithm SHA512 |
            ? {$_.Hash -ne '302FF93AD19303E53C216DBAC8E63DEC42A61048FA7713A9966549916644D0BDBFF17034D923D71AB7C434BAE655969559D01121684B425FD1E4380529C4290B' } |
            % { throw 'Failed hash check.' }
        $_ | Import-Module
    }
