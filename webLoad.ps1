"$([System.IO.Path]::GetTempPath())\BootstraPS.psm1" |
    % {
        Invoke-WebRequest https://raw.githubusercontent.com/alx9r/BootstraPS/c0ddfdeee8a3e4f5a3a89acb8aee530b3fa24f51/BootstraPS.psm1 -OutFile $_ |
            Out-Null
        $_
        Remove-Item $_
    } |
    % {
        Get-FileHash $_ -Algorithm SHA512 |
            ? {$_.Hash -ne '36C2B4D349633F9577DB735C4D3A4B636ECC4A589C2336AF9F05D906C1F41584D088C16523191AAA33492E98B180E27AC5B2077D74D53BD115A16E6EEB2E35A8' } | 
            % { throw 'Failed hash check.' }
        $_ | Import-Module
    }
