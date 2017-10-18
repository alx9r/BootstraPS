"$([System.IO.Path]::GetTempPath())\BootstraPS.psm1" |
    % {
        Invoke-WebRequest https://raw.githubusercontent.com/alx9r/BootstraPS/b587ff1312f940575ce963df9e0472bf05af6713/BootstraPS.psm1 -OutFile $_ |
            Out-Null
        $_
        Remove-Item $_
    } |
    % {
        Get-FileHash $_ -Algorithm SHA512 |
            ? {$_.Hash -ne '9C633584A5E8B949A6536E7272DCCC53BE4C1ADAF9200528F9334609A77E8D475C50663C2291A8645899136FDFFD99876AF077924A8F7D49D42C8B3F494CE3ED' } | 
            % { throw 'Failed hash check.' }
        $_ | Import-Module
    }

Import-WebModule 'https://github.com/pester/Pester/archive/4.0.8.zip' 'Pester.psd1' -PassThru

Remove-Module BootstraPS