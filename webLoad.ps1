"$([System.IO.Path]::GetTempPath())\BootstraPS.psm1" |
    % {
        Invoke-WebRequest https://raw.githubusercontent.com/alx9r/BootstraPS/0e66c59c9cce4e750b1c09826c29f102ca27a9db/BootstraPS.psm1 -OutFile $_ |
            Out-Null
        $_
        Remove-Item $_
    } |
    % {
        Get-FileHash $_ -Algorithm SHA512 |
            ? {$_.Hash -ne '40BE0D9FBE84867EA037BA21CB5438C13C08D49021672817414980D374559209BFB73C0F98948871E4EFF1C507084BE5BB653660DB3E88B4CAD43C1D75F63C66' } | 
            % { throw 'Failed hash check.' }
        $_ | Import-Module
    }
