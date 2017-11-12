. "$PSScriptRoot\..\helpers.ps1"

Describe 'Schannel permissiveness' -Tag 'badssl' {
    $h = @{}
    $allPossibleEntries = @(
            [BootstraPS.Schannel.Protocols].GetEnumValues() | % { @{Protocol=$_ } } |
                % {
                    $x = $_
                    [BootstraPS.Schannel.Role].GetEnumValues() | % { $y = $x.Clone(); $y.Role = $_; $y }
                }
            [BootstraPS.Schannel.Ciphers].GetEnumValues()               | % { @{Cipher=$_} }
            [BootstraPS.Schannel.Hashes].GetEnumValues()                | % { @{Hash  =$_} }
            [BootstraPS.Schannel.KeyExchangeAlgorithms].GetEnumValues() | % { @{KeyExchangeAlgorithm = $_} }
        ) | 
        % {
            $x = $_
            [BootstraPS.Schannel.EnableType].GetEnumValues() | % { $y = $x.Clone(); $y.EnableType = $_; $y }
        }
    It 'stash' {
        $h.originals = $allPossibleEntries | % { Get-SchannelRegistryEntry @_ }
    }
    @(
        @{u = 'https://rc4.badssl.com/';     splat = @{ EnableType = 'Enabled'; Cipher = 'RC4_128_128' } },
        @{u = 'https://rc4-md5.badssl.com/'; splat = @{ EnableType = 'Enabled'; Hash = 'MD5' } },
        @{u = 'https://dh1024.badssl.com/';  splat = @{ EnableType = 'Enabled'; KeyExchangeAlgorithm = 'DH' }}
    ) | % {
    Context $_.u {
        $splat = $_.splat
        $path = [System.IO.Path]::GetTempFileName()
        It 'remove all' {
            $allPossibleEntries | % {
                try 
                {
                    Remove-SchannelRegistryEntry @_
                }
                catch
                {
                    if ( ( $_.Exception | CoalesceExceptionMessage ) -notmatch 'not exist' )
                    {
                        throw
                    }       
                }
            }
        }
        It 'download succeeds' {
            $_.u | Save-WebFile -Path $path
        }
        It 'remove file' {
            $path | Remove-Item -ea Stop    
        }
        It 'Clear-' {
            Clear-SchannelRegistryEntry @splat
        }
        It 'download fails' {
            try
            {
                $_.u | Save-WebFile -Path $path
            }
            catch
            {
                $threw = $true
                $_.Exception |
                    CoalesceExceptionMessage |
                    Should -Match '(Could not establish trust relationship|Could not create SSL/TLS secure channel)'
            }
            $threw | Should -Be $true
        }
        if ( $path | Test-Path )
        {
            It 'remove file' {
                $path | Remove-Item -ea Stop    
            }
        }
    }}
    It 'restore' {
        $h.originals | % {
            try
            {
                $_ | Set-RegistryProperty
            }
            catch
            {
                if ( ( $_.Exception | CoalesceExceptionMessage ) -notmatch 'not exist' )
                {
                    throw
                } 
            }
        }
    }
}

