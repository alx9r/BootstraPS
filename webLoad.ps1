"$([System.IO.Path]::GetTempPath())\BootstraPS.psm1" |
    % {
        Invoke-WebRequest https://raw.githubusercontent.com/alx9r/BootstraPS/1d0bdb3622526b7978e5b5e6a16cd943b44631df/BootstraPS.psm1 -OutFile $_ |
            Out-Null
        $_
        Remove-Item $_
    } |
    % {
        Get-FileHash $_ -Algorithm SHA512 |
            ? {$_.Hash -ne '8651C21516FC4ACA8CF6D5C922098AF60A1CB6D6DE64616835D706099D0C83EA9BDB6DEEA14CC40794C50BD9BAC2F757BFA2E598D33CFD3AC48CBCFA211463FF' } | 
            % { throw 'Failed hash check.' }
        $_ | Import-Module
    }
