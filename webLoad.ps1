"$([System.IO.Path]::GetTempPath())\BootstraPS.psm1" |
    % {
        Invoke-WebRequest https://raw.githubusercontent.com/alx9r/BootstraPS/5cfecbd6f84c88856fc192f0751236918a3693fe/BootstraPS.psm1 -OutFile $_ |
            Out-Null
        $_
        Remove-Item $_
    } |
    % {
        Get-FileHash $_ -Algorithm SHA512 |
            ? {$_.Hash -ne 'E43DD941839ADCC8004865842F2E608039B34F2015B6F96FCF8AC53244709ECFEE828E33580901630550EC0433328CF66949E966586194E343A386542C3629F2' } |
            % { throw 'Failed hash check.' }
        $_ | Import-Module
    }
