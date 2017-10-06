Invoke-WebRequest https://raw.githubusercontent.com/alx9r/BootstraPS/0e64ce9b9fcff1bd532bf35440499609b41944e5/BootstraPS.ps1 |
    % Content |
    Invoke-Expression

Import-WebModule 'https://github.com/pester/Pester/archive/4.0.8.zip' 'Pester.psd1' -PassThru