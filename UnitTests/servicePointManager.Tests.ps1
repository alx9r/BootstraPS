Remove-Module Bootstraps
Import-Module "$PSScriptRoot\..\Bootstraps.psm1"

InModuleScope Bootstraps {

Describe Merge-SecurityProtocol {
    It 'null' {
        { $null | Merge-SpManagerProtocol -ea Stop } | Should throw
    }
    It 'one' {
        $r = [System.Net.SecurityProtocolType]::Ssl3 | Merge-SpManagerProtocol
        $r | Should -Be ([System.Net.SecurityProtocolType]::Ssl3)
    }
    It 'two' {
        $r = [System.Net.SecurityProtocolType]::Ssl3,
             [System.Net.SecurityProtocolType]::Tls |
             Merge-SpManagerProtocol
        $r | Should -be ([System.Net.SecurityProtocolType]::Ssl3 -bor [System.Net.SecurityProtocolType]::Tls)
    }
}
Describe Assert-SpManagerProtocolEnabled {
    Mock Get-SpManagerProtocol { [System.Net.SecurityProtocolType]::Ssl3 }
    It 'succeeds' {
        Assert-SpManagerProtocolEnabled 'Ssl3'
    }
    It 'throws' {
        { Assert-SpManagerProtocolEnabled 'Tls' } |
            Should -Throw 'is not set'
    }
}
Describe Assert-SpManagerProtocolDisabled {
    Mock Get-SpManagerProtocol { [System.Net.SecurityProtocolType]::Ssl3 }
    It 'succeeds' {
        Assert-SpManagerProtocolDisabled 'Tls'
    }
    It 'throws' {
        { Assert-SpManagerProtocolDisabled 'Ssl3' } |
            Should -Throw 'is set'
    }
}
}