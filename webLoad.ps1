"$([System.IO.Path]::GetTempPath())\BootstraPS.psm1" |
    % {
        Invoke-WebRequest https://raw.githubusercontent.com/alx9r/BootstraPS/12ae959670e648c40736ca7f4afd9508d18e0abb/BootstraPS.psm1 -OutFile $_ |
            Out-Null
        $_
        Remove-Item $_
    } |
    % {
        Get-FileHash $_ -Algorithm SHA512 |
            ? {$_.Hash -ne 'A43AA05320DC17D0A241BD9876EB145593486CF46B5EA71C059B045DFF193E28753041384EA2D000B9BF146C356BB12A8AA2CB8D3EF688A8EE528275D192EC3B' } | 
            % { throw 'Failed hash check.' }
        $_ | Import-Module
    }
