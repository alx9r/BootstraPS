. "$PSScriptRoot\..\helpers.ps1"

Describe 'Schannel permissiveness' {
    $rc4ciphers = [BootstraPS.Schannel.Ciphers].GetEnumNames() | ? { $_ -match 'RC4' }

    @(
        @{u = 'https://rc4.badssl.com/';     splat = @{ EnableType = 'Enabled'; Cipher = 'RC4_128_128' } },
        @{u = 'https://rc4-md5.badssl.com/'; splat = @{ EnableType = 'Enabled'; Hash = 'MD5' } },
        @{u = 'https://dh1024.badssl.com/';  splat = @{ EnableType = 'Enabled'; KeyExchangeAlgorithm = 'DH' }}
    ) |
    % {
    Context $_.u {
        $h = @{}
        $splat = $_.splat
        $path = [System.IO.Path]::GetTempFileName()
        It 'get original' {
            $h.original = Get-SchannelRegistryEntry @splat
        }
        It 'Remove-' {
            try 
            {
                Remove-SchannelRegistryEntry @splat
            }
            catch
            {
                if ( ( $_.Exception | CoalesceExceptionMessage ) -notmatch 'not exist' )
                {
                    throw
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
        It 'restore' {
            $h.original | Set-RegistryProperty
        }
    }}
}

