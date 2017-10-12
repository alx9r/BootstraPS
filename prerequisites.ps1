Invoke-WebRequest https://raw.githubusercontent.com/alx9r/BootstraPS/master/BootstraPS.psm1 |
    % Content |
    Invoke-Expression

Import-WebModule 'https://github.com/pester/Pester/archive/4.0.8.zip' 'Pester.psd1' -PassThru