[System.IO.Path]::GetTempFileName() |
    % {
        Invoke-WebRequest https://raw.githubusercontent.com/alx9r/BootstraPS/e49061bab64776e3a758cdd5799d7e7ec4cb77b7/BootstraPS.psm1 -OutFile $_ |
            Out-Null
        $_
        Remove-Item $_
    } |
    % {
        Get-FileHash $_ -Algorithm SHA512 |
            ? {$_.Hash -ne '098E8D5AABAA5390180BB8D7BD7A89B9629EB5DCB15096C3EADEB8C6383376B82E3A66A9C49C9AF7EBDD26C6A5D3E69A11DD315D90755021C123AB4139B2C640' } | 
            % { throw 'Failed hash check.' }
        $_ | Get-Item | Get-Content -Raw | Invoke-Expression
    }
