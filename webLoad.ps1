"$([System.IO.Path]::GetTempPath())\BootstraPS.psm1" |
    % {
        Invoke-WebRequest https://raw.githubusercontent.com/alx9r/BootstraPS/e3a4fd1009a0e39c6f46e1cbf79ddbb69368f853/BootstraPS.psm1 -OutFile $_ |
            Out-Null
        $_
        Remove-Item $_
    } |
    % {
        Get-FileHash $_ -Algorithm SHA512 |
            ? {$_.Hash -ne '269B254EB21B8C46BDD64A9CC7DFC64940CDB8701D8CFE5DDA6A20C93EB3A4088BE3892AEA3ADFD7DFAC4BF8E39C956A117D0ECA313264FAFD223B30E2DD35BC' } | 
            % { throw 'Failed hash check.' }
        $_ | Import-Module
    }
