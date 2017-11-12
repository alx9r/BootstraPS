Get-Module Bootstraps | Remove-Module
Import-Module "$PSScriptRoot\..\Bootstraps.psm1"

. "$PSScriptRoot\..\helpers.ps1"
Add-Type -AssemblyName System.Net.Http.WebRequest

function get
{
    param(
        [Parameter(Position=1)]
        $CallBack,

        $Uri = 'https://raw.githubusercontent.com/alx9r/BootstraPS/master/LICENSE'
    )
    $handler = [System.Net.Http.WebRequestHandler]::new()
    $handler.ServerCertificateValidationCallback = $CallBack
    $client = [System.Net.Http.HttpClient]::new($handler)
    $async = $client.GetAsync($Uri)
    $async.AsyncWaitHandle.WaitOne()
    return $async
}

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
            Context '[BootstraPS.Concurrency.CertificateValidator]' {
                It 'CertValidator scriptblock callback succeeds: <sb>' -TestCases @(
                    @{sb={$true}}
                    @{sb={$true,$true}}
                ) {
                    param($sb)
                    $a = get ([BootstraPS.Concurrency.CertificateValidator]::new($sb).Callback)
                    $a.Exception | ?{$_} | % { throw $_ }
                }
                It 'CertValidator scriptblock with error succeeds when ErrorActionPreference is overridden' {
                    $a = get ([BootstraPS.Concurrency.CertificateValidator]::new(
                        {Write-Error 'some error'; $true},
                        $null,
                        [psvariable]::new('ErrorActionPreference','Continue')
                    ).Callback)
                    $a.Exception | ?{$_} | % { throw $_ }
                }
                It 'CertValidator scriptblock throws: <sb>' -TestCases @(
                    @{sb={};            m='cert.*invalid'}
                    @{sb={$null};       m='cert.*invalid'}
                    @{sb={$true,$null}; m='cert.*invalid'}
                    @{sb={$null,$true}; m='cert.*invalid'}
                    @{sb={$false};      m='cert.*invalid'}
                    @{sb={$false,$true};m='cert.*invalid'}
                    @{sb={$false,$true};m='cert.*invalid'}
                    @{sb={throw 'something'};m='something'}
                    @{sb={1 | % {1}};   m='cert.*invalid'}
                    @{sb={Write-Error 'some error'};m='some error'}
                    @{sb={Write-Error 'some error';$true};m='some error'}
                ) {
                    param($sb,$m)

                    $a = get ([BootstraPS.Concurrency.CertificateValidator]::new($sb).Callback)
                    $a.Exception | 
                        CoalesceExceptionMessage |
                        Should -Match $m
                }
            }
            Context 'variables' {
                Context 'no inject' {
                    It 'scriptblock does not set local object' {
                        $v = 'local value'
                        $cv = [BootstraPS.Concurrency.CertificateValidator]::new({$v = 'scriptblock value'})
                        get $cv.Callback
                        $v | Should -Be 'local value'
                    }
                    It 'scriptblock does not set value of contents of local object' {
                        $h = @{v='local value'}
                        $cv = [BootstraPS.Concurrency.CertificateValidator]::new({$h.v = 'scriptblock value'})
                        get $cv.Callback
                        $h.v | Should -be 'local value'
                    }
                    It 'DollarBar contents' {
                        $h = @{DollarBar='original value'}
                        $cv = [BootstraPS.Concurrency.CertificateValidator]::new({$h.DollarBar = $_})

                        get $cv.Callback

                        $h.DollarBar | Should -be 'original value'
                    }
                }
                Context 'inject' {
                    It 'scriptblock does not set local object' {
                        $v = 'local value'
                        $cv = [BootstraPS.Concurrency.CertificateValidator]::new(
                            {$v = 'scriptblock value'},
                            $null,
                            (Get-Variable v),
                            $null
                        )
                        get $cv.Callback
                        $v | Should -Be 'local value'
                    }
                    It 'scriptblock sets value of contents of local object' {
                        $h = @{v='local value'}
                        $cv = [BootstraPS.Concurrency.CertificateValidator]::new(
                            {$h.v = 'scriptblock value'},
                            $null,
                            (Get-Variable h),
                            $null
                        )
                        get $cv.Callback
                        $h.v | Should -Be 'scriptblock value'
                    }
                    It 'DollarBar contents' {
                        $h = @{DollarBar='original value'}
                        $cv = [BootstraPS.Concurrency.CertificateValidator]::new(
                            {$h.DollarBar = $_},
                            $null,
                            (Get-Variable h),
                            $null
                        )

                        get $cv.Callback

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
Describe 'WebRequestHandler (badssl)' -Tag 'badssl' {
    # Ideally this would be merged with the previous describe block.
    # It is separated out because of the "outermost test group" limitation
    # of Pester 4.0.8.
    Context 'httpclient' {
        Context 'ServerCertificateValidationCallback' {
            Context '[BootstraPS.Concurrency.CertificateValidator]' {
                Context 'built-in checks' {
                    It 'performs built-in checks by default' {
                        $a = get ([BootstraPS.Concurrency.CertificateValidator]::new({$true}).Callback) -Uri 'https://self-signed.badssl.com'
                        $a.Exception |
                            CoalesceExceptionMessage |
                            Should -Match 'SSL Policy Error'
                    }
                    It 'skips built-in check' {
                        $a = get ([BootstraPS.Concurrency.CertificateValidator]::new(
                                {$true},
                                $null,
                                $null,
                                $null,
                                $null,
                                $null,
                                $true # skipBuiltInSslPolicyChecks
                            ).Callback) -Uri 'https://self-signed.badssl.com'
                        $a.Exception | Should -BeNullOrEmpty
                    }
                }
            }
        }
    }
}