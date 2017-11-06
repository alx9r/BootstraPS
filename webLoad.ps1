"$([System.IO.Path]::GetTempPath())\BootstraPS.psm1" |
    % {
        Invoke-WebRequest https://raw.githubusercontent.com/alx9r/BootstraPS/b5573809ed43fb8c8b16dd2ec19c956376159587/BootstraPS.psm1 -OutFile $_ |
            Out-Null
        $_
        Remove-Item $_
    } |
    % {
        Get-FileHash $_ -Algorithm SHA512 |
            ? {$_.Hash -ne '0D4D195FE8A1C2DA119F5988944F590942F490BB21E61E8E19309D069F690046C13D91C054B9922C8EF6D21874771659A80F4F97A6983EB9C07D92C6BCDE4046' } | 
            % { throw 'Failed hash check.' }
        $_ | Import-Module
    }
