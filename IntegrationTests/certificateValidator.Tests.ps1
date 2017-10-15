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
            Context '[CertificateValidator]' {
                It 'CertValidator scriptblock callback succeeds: <n>' -TestCases @(
                    @{n='returns true';      sb={$true}}
                    @{n='returns true twice';sb={$true,$true}}
                ) {
                    param($n,$sb)
                    $a = get ([CertificateValidator]::new($sb).Delegate)
                    $a.Exception | ?{$_} | % { throw $_ }
                }
                It 'CertValidator scriptblock: <n>' -TestCases @(
                    @{n='returns false';     sb={$false};      m='cert.*invalid'}
                    @{n='returns false true';sb={$false,$true};m='cert.*invalid'}
                    @{n='returns true false';sb={$false,$true};m='cert.*invalid'}
                    @{n='throws';       sb={throw 'something'};m='something'}
                ) {
                    param($n,$sb,$m)

                    $a = get ([CertificateValidator]::new($sb).Delegate)
                    $a.Exception | 
                        CoalesceExceptionMessage |
                        Should -Match $m
                }
            }
            Context 'variables' {
                Context 'no inject' {
                    It 'scriptblock does not set local object' {
                        $v = 'local value'
                        $cv = [CertificateValidator]::new({$v = 'scriptblock value'})
                        get $cv.Delegate
                        $v | Should -Be 'local value'
                    }
                    It 'scriptblock sets value of contents of local object' {
                        $h = @{v='local value'}
                        $cv = [CertificateValidator]::new({$h.v = 'scriptblock value'})
                        get $cv.Delegate
                        $h.v | Should -Be 'scriptblock value'
                    }
                    It 'DollarBar contents' {
                        $h = @{DollarBar='original value'}
                        $cv = [CertificateValidator]::new({$h.DollarBar = $_})

                        get $cv.Delegate

                        $h.DollarBar.sender | Should -Not -BeNullOrEmpty
                        $h.DollarBar.certificate | Should -BeOfType ([System.Security.Cryptography.X509Certificates.X509Certificate2])
                        $h.DollarBar.chain | Should -BeOfType ([System.Security.Cryptography.X509Certificates.X509Chain])
                        $h.DollarBar.sslPolicyErrors | Should -BeOfType ([System.Net.Security.SslPolicyErrors])
                    }
                }
                Context 'inject' {
                    It 'scriptblock does not set local object' {
                        $v = 'local value'
                        $cv = [CertificateValidator]::new(
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
                        $cv = [CertificateValidator]::new(
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
                        $cv = [CertificateValidator]::new(
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