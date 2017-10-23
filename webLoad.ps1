"$([System.IO.Path]::GetTempPath())\BootstraPS.psm1" |
    % {
        Invoke-WebRequest https://raw.githubusercontent.com/alx9r/BootstraPS/f3fdf4e575b5db361f4cb755943730d067c1cca1/BootstraPS.psm1 -OutFile $_ |
            Out-Null
        $_
        Remove-Item $_
    } |
    % {
        Get-FileHash $_ -Algorithm SHA512 |
            ? {$_.Hash -ne '67C5B1A7ED1EA2585E7A5874A9261193749FD0F6EC66403D0E7EAA8E3A20D1F1B32669AF093F8BCD40CFA36F4BEBF3606609ABADA0CEC96D7B55305EAE626C39' } | 
            % { throw 'Failed hash check.' }
        $_ | Import-Module
    }
