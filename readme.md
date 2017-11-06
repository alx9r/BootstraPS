<!--
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
!!!!! This document is script-generated.  !!!!!
!!!!! Do not directly edit this document. !!!!!
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
-->
[![Build status](https://ci.appveyor.com/api/projects/status/fy38i5dvionpq2p9?svg=true)](https://ci.appveyor.com/project/alx9r/bootstraps)

# BootstraPS

The BootstraPS contains minimal scripts for bootstrapping the setup of more elaborate PowerShell configurations. 

## Usage

BootstraPS is designed to have a very small footprint.  To use the BootstrapPS command simply import `BootstraPS.psm1` in one of the following ways.

**from Disk**

If you already have `BootstraPS.psm1` on your computer, just imported it as follows:

```PowerShell
Import-Module .\BootstraPS.psm1
```

where `.\BootStraPS.psm1` is the path to the file on your computer.

**from Github**

You can also import `BootstraPS.psm1` directly from Github:

```PowerShell
"$([System.IO.Path]::GetTempPath())\BootstraPS.psm1" |
    % {
        Invoke-WebRequest https://raw.githubusercontent.com/alx9r/BootstraPS/8315282a987fc3fc2e647605612e7d8135435048/BootstraPS.psm1 -OutFile $_ |
            Out-Null
        $_
        Remove-Item $_
    } |
    % {
        Get-FileHash $_ -Algorithm SHA512 |
            ? {$_.Hash -ne 'FFCBF7D37D25DCA10D36FE1E83A8A5FA269F0B59E2A1623CEEC91F47F5DD68B6C50EA18CD9C25DAAF4E91D4C9872B5DC91719C934B8B8054B02C8C6B65C4DD62' } | 
            % { throw 'Failed hash check.' }
        $_ | Import-Module
    }
```

Note that the SHA512 hash of the file is checked prior to the call to `Import-Module` to confirm that the download is authentic.

Once the Bootstraps module is in-memory you can import modules directly from, for example, github.com:

```PowerShell
'Datum' | Import-WebModule @{
    Datum = @{
        Uri = 'https://github.com/gaelcolas/Datum/archive/555221cd828b1bc42425b6233389bd1b9d869597.zip'
        Manifest = 'Datum.psd1'
    }
    @{ 
        ModuleName='ProtectedData'
        ModuleVersion = '4.1.0'
    } = 'https://github.com/dlwyatt/ProtectedData/releases/download/4.1.0/ProtectedData.zip'
    'powershell-yaml' = 'https://github.com/cloudbase/powershell-yaml/archive/9c693dfb71ffa00fe6dd171136e42ee7705ea363.zip'
}
```

There are a few notable things about this example.  This particular revision of `Datum` requires `ProtectedData` version 4.1.0 which requires `powershell-yaml`.   `Import-WebModule` works this out based on each module's module manifest and imports each module as necessary

`Datum` is still under development and has not yet incremented its version number (at the time this is being written).  `powershell-yaml` has been released (it can be found using PowerShellGet's `Find-Module` command) but it is difficult to correlate the revision that you get using `Find-Module` with source code because the `powershell-yaml` project doesn't seem to use github releases or otherwise publish metadata that would make such correlation obvious.  

The absence of official releases or metadata to correlate releases with source code seems to be commonplace for PowerShell modules, in particular for those that are new or under active development.  To sidestep these problems we use `Uri`s for archives containing the particular revision.  Because github automatically makes these available, using `Import-WebModule` does not depend on each project's release management practices to deploy the revision of module we need.

## Commands

BootstraPS exports the following commands:

### Save-WebFile

```

NAME
    Save-WebFile
    
SYNOPSIS
    Save a file from the web.
    
    
SYNTAX
    Save-WebFile [-CertificateValidator <ScriptBlock>] [-Path] <String> -Uri 
    <Uri> [-SecurityPolicy {Normal | DangerousPermissive | Strict}] 
    [<CommonParameters>]
    
    
DESCRIPTION
    Save-WebFile downloads a file from a server at Uri and saves it at Path.
    
    A scriptblock can optionally be passed to Save-WebFile's 
    CertificateValidator parameter to validate an https server's certificate 
    when Save-WebFile connects to the server.  CertificateValidator is invoked 
    by the system callback with its own runspace and session state.  Because of 
    this, the commands in the CertificateValidator scriptblock do not have 
    access to the variables and modules at the Save-WebFile call site.
    
    BootstraPS exports a number of commands to help with validating 
    certificates.  Those commands are available to the CertificateValidator 
    scriptblock but other commands are not.
    
    The system might invoke CertificateValidator on a different thread from the 
    thread that invoked Save-WebFile.
    
    The SecurityPolicy parameter can be provided to alter the permissiveness of 
    Save-WebFile's TLS/SSL handshake according to the following table:
    
        +---------------------+-------------+--------------------------------+
        |                     | certificate |            allows              |
        |  SecurityPolicy     | validation  +------+------------+------------+
        |                     | performed   | http | protocols  | algorithms |
        +---------------------+-------------+------+------------+------------+
        | Normal (Default)    | SD, user    | no   | SD         | SD         |
        | Strict              | SD, user    | no   | restricted | restricted |
        | DangerousPermissive | user        | yes  | SD         | SD         |
        +---------------------+-------------+------+------------+------------+
    
        SD - system default
        user - certificates are validated by the user-defined 
    CertificateValidator parameter if it is provided
        retricted - security policy that may be more restrictive than system 
    defaults are imposed
    
    The exact nature of system default certificate validation performed and 
    protocols and algorithms allowed may change from computer to computer and 
    time to time.  Furthermore, the additional restrictions imposed by 
    Save-WebFile may change from revision to revision of this implementation.
    



-CertificateValidator <ScriptBlock>
    A scriptblock that is invoked by the system when connecting to Uri.  
    CertificateValidator's output tells the system whether the certificate is 
    valid.  The system interprets the certificate to be valid if all outputs 
    from CertificateValidator are $true.  If any output is $false, $null, or a 
    non-boolean value or if there is no output, the system interprets the 
    certificate to be invalid which causes Save-WebFile to throw an exception 
    without downloading any file.  The automatic variable $_ is available in 
    the scriptblock and has the properties sender, certificate, chain, and 
    sslPolicyErrors whose values are the arguments passed by the system to the 
    System.Net.Security.RemoteCertificateValidationCallback delegate.
    
    Required?                    false
    Position?                    named
    Default value                
    Accept pipeline input?       false
    Accept wildcard characters?  false
    

-Path <String>
    The path to save the file.
    
    Required?                    true
    Position?                    2
    Default value                
    Accept pipeline input?       true (ByPropertyName)
    Accept wildcard characters?  false
    

-Uri <Uri>
    The Uri from which to download the file.
    
    Required?                    true
    Position?                    named
    Default value                
    Accept pipeline input?       true (ByValue)
    Accept wildcard characters?  false
    

-SecurityPolicy
    The strictness of the policy Save-WebFile applies when establishing 
    communication with the server.
    
    Required?                    false
    Position?                    named
    Default value                
    Accept pipeline input?       false
    Accept wildcard characters?  false
    




```
### Import-WebModule

```

NAME
    Import-WebModule
    
SYNOPSIS
    Imports a module from the web.
    
    
SYNTAX
    Import-WebModule [-Uri] <Uri> [[-ManifestFileFilter] <String>] 
    [-CertificateValidator <ScriptBlock>] [-SecurityPolicy {Normal | 
    DangerousPermissive | Strict}] [-PassThru] [<CommonParameters>]
    
    Import-WebModule -ModuleSpec <ModuleSpecification> [-SourceLookup] 
    <Hashtable> [-PassThru] [<CommonParameters>]
    
    
DESCRIPTION
    Import-WebModule downloads and imports a module and, optionally, the 
    required modules mentioned in the module's manifest.  Import-WebModule 
    works with modules that meet the following criteria:
     - has a module manifest
     - is otherwise a well-formed PowerShell module
     - is compressed into a single archive file with the .zip extension
    
    If Import-WebModule encounters a module that requires another module and 
    SourceLookup is provided, Import-WebModule looks for a source for the 
    required module in SourceLookup and recursively downloads and imports the 
    required modules.
    
    Import-WebModule downloads and expands modules to temporary locations.  
    Import-WebModule deletes the archives immediately after expansion.  
    Import-WebModule attempts to delete the files of the expanded module 
    immediately after import but will silently leave them behind if that is not 
    possible.  This can occur, for example, when the module contains an 
    assembly that becomes locked when the module is loaded.
    
    Import-WebModule invokes Save-WebFile to download and save the file.  The 
    Uri, CertificateValidator, and SecurityPolicy parameters are passed to 
    Save-WebFile unaltered.
    



-ModuleSpec <ModuleSpecification>
    The module specification used to select the Uri from SourceLookup.
    
    Required?                    true
    Position?                    named
    Default value                
    Accept pipeline input?       true (ByValue)
    Accept wildcard characters?  false
    

-SourceLookup <Hashtable>
    A hashtable used by Import-WebModule to lookup the Uri, ManifestFileFilter, 
    CertificateValidator, and SecurityPolicy for a module.
    
    It must be possible to convert each key of SourceLookup to ModuleSpec.
    
    Values of SourceLookup must either be convertible to Uri or a hashtable 
    containing at least two entries: Uri and ManifestFileFilter.  When 
    importing a module that requires other modules, SourceLookup should include 
    a key value pair for each module that is required.
    
    Required?                    true
    Position?                    2
    Default value                
    Accept pipeline input?       false
    Accept wildcard characters?  false
    

-Uri <Uri>
    The Uri from which to download the module. This parameter is passed to 
    Save-WebFile unaltered.  See help Save-WebFile for more information.
    
    Required?                    true
    Position?                    2
    Default value                
    Accept pipeline input?       false
    Accept wildcard characters?  false
    

-ManifestFileFilter <String>
    A filter passed by Import-WebModule to Get-ChildItem to select the manifest 
    file for the module.
    
    Required?                    false
    Position?                    3
    Default value                *.psd1
    Accept pipeline input?       false
    Accept wildcard characters?  false
    

-CertificateValidator <ScriptBlock>
    This parameter is passed to Save-WebFile unaltered.  See help Save-WebFile 
    for more information.
    
    Required?                    false
    Position?                    named
    Default value                
    Accept pipeline input?       false
    Accept wildcard characters?  false
    

-SecurityPolicy
    This parameter is passed to Save-WebFile unaltered.  See help Save-WebFile 
    for more information.
    
    Required?                    false
    Position?                    named
    Default value                
    Accept pipeline input?       false
    Accept wildcard characters?  false
    

-PassThru [<SwitchParameter>]
    Returns the object output by the calls to Import-Module -PassThru. By 
    default, this cmdlet does not generate any output.
    
    Required?                    false
    Position?                    named
    Default value                False
    Accept pipeline input?       false
    Accept wildcard characters?  false
    




```
