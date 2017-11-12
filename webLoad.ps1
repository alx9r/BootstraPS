"$([System.IO.Path]::GetTempPath())\BootstraPS.psm1" |
    % {
        Invoke-WebRequest https://raw.githubusercontent.com/alx9r/BootstraPS/ccb59716d6609edd635df3aa32894874c5fcf96b/BootstraPS.psm1 -OutFile $_ |
            Out-Null
        $_
        Remove-Item $_
    } |
    % {
        Get-FileHash $_ -Algorithm SHA512 |
            ? {$_.Hash -ne 'F1F192235F64D9575C944F9BF68C05848F1959CAA305BB62F34A382FB61E219B462F299AD2DC4045466AF2B8F018196887F90D58C71A85C206147B7775932CAC' } |
            % { throw 'Failed hash check.' }
        $_ | Import-Module
    }
