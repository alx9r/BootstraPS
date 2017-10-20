Get-Module Bootstraps | Remove-Module
Import-Module "$PSScriptRoot\..\Bootstraps.psm1"

. "$PSScriptRoot\..\helpers.ps1"
Add-Type -AssemblyName System.Net.Http.WebRequest

Describe 'WebRequestHandler' {
    It 'create' {
        [System.Net.Http.WebRequestHandler]::new()
    }
    It 'add callback' {
        $h = [System.Net.Http.WebRequestHandler]::new()
        $h.ServerCertificateValidationCallback = {}
    }
    It 'use to create httpclient' {
        $h = [System.Net.Http.WebRequestHandler]::new()
        $h.ServerCertificateValidationCallback = {}
        [System.Net.Http.HttpClient]::new($h)
    }
    Context 'httpclient' {
        function get
        {
            param(
                [Parameter(Position=1)]
                $CallBack
            )
            $handler = [System.Net.Http.WebRequestHandler]::new()
            $handler.ServerCertificateValidationCallback = $CallBack
            $client = [System.Net.Http.HttpClient]::new($handler)
            $async = $client.GetAsync('https://raw.githubusercontent.com/alx9r/BootstraPS/master/LICENSE')
            $async.AsyncWaitHandle.WaitOne()
            return $async
        }
        It 'use httpclient' {
            $a = get
            $r = $a.Result.Content.ReadAsStringAsync().Result 
            $r | Should -match 'LICENSE'
        }
        Context 'ServerCertificateValidationCallback' {
            It 'scriptblock callback throw "no runspace"' {
                $a = get ({})
                $a.Exception.InnerException.InnerException.InnerException | Should -Match 'no Runspace'
            }
            Context '[BootstraPS.CertificateValidator]' {
                It 'CertValidator scriptblock callback succeeds: <sb>' -TestCases @(
                    @{sb={$true}}
                    @{sb={$true,$true}}
                ) {
                    param($sb)
                    $a = get ([BootstraPS.CertificateValidator]::new($sb).Delegate)
                    $a.Exception | ?{$_} | % { throw $_ }
                }
                It 'CertValidator scriptblock with error succeeds when ErrorActionPreference is overridden' {
                    $a = get ([BootstraPS.CertificateValidator]::new(
                        {Write-Error 'some error'; $true},
                        $null,
                        [psvariable]::new('ErrorActionPreference','Continue')
                    ).Delegate)
                    $a.Exception | ?{$_} | % { throw $_ }
                }
                It 'CertValidator scriptblock throws: <sb>' -TestCases @(
                    @{sb={$false};      m='cert.*invalid'}
                    @{sb={$false,$true};m='cert.*invalid'}
                    @{sb={$false,$true};m='cert.*invalid'}
                    @{sb={throw 'something'};m='something'}
                    @{sb={1 | % {1}};   m='cert.*invalid'}
                    @{sb={Write-Error 'some error'};m='some error'}
                    @{sb={Write-Error 'some error';$true};m='some error'}
                ) {
                    param($sb,$m)

                    $a = get ([BootstraPS.CertificateValidator]::new($sb).Delegate)
                    $a.Exception | 
                        CoalesceExceptionMessage |
                        Should -Match $m
                }
            }
            Context 'variables' {
                Context 'no inject' {
                    It 'scriptblock does not set local object' {
                        $v = 'local value'
                        $cv = [BootstraPS.CertificateValidator]::new({$v = 'scriptblock value'})
                        get $cv.Delegate
                        $v | Should -Be 'local value'
                    }
                    It 'scriptblock does not set value of contents of local object' {
                        $h = @{v='local value'}
                        $cv = [BootstraPS.CertificateValidator]::new({$h.v = 'scriptblock value'})
                        get $cv.Delegate
                        $h.v | Should -be 'local value'
                    }
                    It 'DollarBar contents' {
                        $h = @{DollarBar='original value'}
                        $cv = [BootstraPS.CertificateValidator]::new({$h.DollarBar = $_})

                        get $cv.Delegate

                        $h.DollarBar | Should -be 'original value'
                    }
                }
                Context 'inject' {
                    It 'scriptblock does not set local object' {
                        $v = 'local value'
                        $cv = [BootstraPS.CertificateValidator]::new(
                            {$v = 'scriptblock value'},
                            $null,
                            (Get-Variable v),
                            $null
                        )
                        get $cv.Delegate
                        $v | Should -Be 'local value'
                    }
                    It 'scriptblock sets value of contents of local object' {
                        $h = @{v='local value'}
                        $cv = [BootstraPS.CertificateValidator]::new(
                            {$h.v = 'scriptblock value'},
                            $null,
                            (Get-Variable h),
                            $null
                        )
                        get $cv.Delegate
                        $h.v | Should -Be 'scriptblock value'
                    }
                    It 'DollarBar contents' {
                        $h = @{DollarBar='original value'}
                        $cv = [BootstraPS.CertificateValidator]::new(
                            {$h.DollarBar = $_},
                            $null,
                            (Get-Variable h),
                            $null
                        )

                        get $cv.Delegate

                        $h.DollarBar.sender | Should -Not -BeNullOrEmpty
                        $h.DollarBar.certificate | Should -BeOfType ([System.Security.Cryptography.X509Certificates.X509Certificate2])
                        $h.DollarBar.chain | Should -BeOfType ([System.Security.Cryptography.X509Certificates.X509Chain])
                        $h.DollarBar.sslPolicyErrors | Should -BeOfType ([System.Net.Security.SslPolicyErrors])
                    }
                }
            }
        }
    }
}