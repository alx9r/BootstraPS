"$([System.IO.Path]::GetTempPath())\BootstraPS.psm1" |
    % {
        Invoke-WebRequest https://raw.githubusercontent.com/alx9r/BootstraPS/0613641e6f76dd2c9a788de605405af19e9ba87a/BootstraPS.psm1 -OutFile $_ |
            Out-Null
        $_
        Remove-Item $_
    } |
    % {
        Get-FileHash $_ -Algorithm SHA512 |
            ? {$_.Hash -ne 'D83A05E4F775131B5A5075D29EEE5D273A8E0539EF2975A1EBD0B43A65D3763BD6AD9870F3250EE7B01D78B0F225B2C19F2FF8E37C0E2086D6F4FDF473232385' } | 
            % { throw 'Failed hash check.' }
        $_ | Import-Module
    }
