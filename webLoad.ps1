"$([System.IO.Path]::GetTempPath())\BootstraPS.psm1" |
    % {
        Invoke-WebRequest https://raw.githubusercontent.com/alx9r/BootstraPS/12ae959670e648c40736ca7f4afd9508d18e0abb/BootstraPS.psm1 -OutFile $_ |
            Out-Null
        $_
        Remove-Item $_
    } |
    % {
        Get-FileHash $_ -Algorithm SHA512 |
            ? {$_.Hash -ne '15B77DED46A17E629B502B0C6A92B6D420FF8D5BA31ADA914FA078AB121A10629FD46C306EA095EF8E64279B315A366667A9ED38CAB7088A962AC98C0B67EEE2' } | 
            % { throw 'Failed hash check.' }
        $_ | Import-Module
    }
