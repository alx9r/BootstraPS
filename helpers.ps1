Import-Module "$PSScriptRoot\BootstraPS.psm1" -Force

function Get-LastCommitHash
{
    param
    (
        [Parameter(Mandatory,
                   ValueFromPipeline)]
        [System.IO.FileInfo]
        $FileInfo
    )
    process
    {
        $FileInfo.Directory | Push-Location
        try
        {
            git.exe log $FileInfo.FullName |
                select -First 1 |
                Select-String '^commit (?<hash>[0-9a-fA-F]*)' | 
                % Matches | 
                % Groups | 
                ? {$_.Name -eq 'hash' } | 
                % Value
        }
        finally
        {
            Pop-Location
        }
    }
}

function Get-RepoRelativePath
{
    param
    (
        [Parameter(Mandatory,
                   ValueFromPipeline)]
        [System.IO.FileInfo]
        $FileInfo
    )
    process
    {
        Push-Location $PSScriptRoot
        try
        {
            $FileInfo | Resolve-Path -Relative
        }
        finally
        {
            Pop-Location
        }
    }
}

function Get-RawContentUri
{
    param
    (
        [Parameter(Mandatory,
                   ValueFromPipeline)]
        [System.IO.FileInfo]
        $FileInfo
    )
    process
    {
        $hash = $FileInfo | Get-LastCommitHash
        $repoRelativePath = $FileInfo |
            Get-RepoRelativePath
        [uri]::new(
        [uri]::new([uri]'https://raw.githubusercontent.com/alx9r/BootstraPS/',
                   "$hash/"),
                   $repoRelativePath
        )
    }
}

function New-WebloadPs1
{
    $hash = Get-FileHash $PSScriptRoot\BootstraPS.psm1 -Algorithm SHA512 | % Hash
    $uri = Get-Item $PSScriptRoot\BootstraPS.psm1 | Get-RawContentUri
    Get-Content $PSScriptRoot\webLoad.ps1.source |
        % { $_ -replace '__SHA512__',$hash } |
        % { $_ -replace '__Uri__',$uri }
}

function Get-ReadmeHelp
{
    param
    (
        [Parameter(Mandatory,
                   ValueFromPipeline)]
        [System.Management.Automation.CommandInfo]
        $CommandInfo
    )
    process
    {
        & {
            $CommandInfo | 
                Get-Help |
                Out-String -Width 80 |
                % { $_.Split(([string[]]'RELATED LINKS'),[System.StringSplitOptions]::None) } |
                select -First 1
            $CommandInfo |
                Get-Help -Parameter * |
                Out-String -Width 80
        } |
        % { $_.Split(([string[]]"`r`n"),[System.StringSplitOptions]::None) }
    }
}

function New-ReadmeMd
{
    '<!--'
    '!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!'
    '!!!!! This document is script-generated.  !!!!!'
    '!!!!! Do not directly edit this document. !!!!!'
    '!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!'
    '-->'
    Get-Content $PSScriptRoot\readme.md.source |
        % {
            . @{
                $true = { Get-Content $PSScriptRoot\webload.ps1 }
                $false = { $_ }
            }.($_ -match '__webloadPs1__')
        } |
        % {
            . @{
                $true = { Get-Command Import-WebModule | Get-ReadmeHelp }
                $false = { $_ }
            }.($_ -match '__help__')
        }
}