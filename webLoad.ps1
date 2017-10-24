"$([System.IO.Path]::GetTempPath())\BootstraPS.psm1" |
    % {
        Invoke-WebRequest https://raw.githubusercontent.com/alx9r/BootstraPS/333f738064383d60922a67ff53ee88964d1be9ca/BootstraPS.psm1 -OutFile $_ |
            Out-Null
        $_
        Remove-Item $_
    } |
    % {
        Get-FileHash $_ -Algorithm SHA512 |
            ? {$_.Hash -ne 'C81F6D3187F58BF031C2333B707917067C4ECB3E8542A64B8E82E823D39D068389A723B4B056B35B287F9752BFB8DDB6D0586A6D9564FA36AD2C2E022A53B52A' } | 
            % { throw 'Failed hash check.' }
        $_ | Import-Module
    }
