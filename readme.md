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

BootstraPS is designed to have a very small footprint.  To use the BootstrapPS command simply load `BootstraPS.ps1` into memory in one of the following ways.

**from Disk**

If you already have `BootstraPS.ps1` on your computer, just dot-source it to load the commands into memory:

```PowerShell
. .\BootstraPS.ps1
```

**from Github**

You can also load `BootstraPS.ps1` directly from Github:

```PowerShell
[System.IO.Path]::GetTempFileName() |
    % {
        Invoke-WebRequest https://raw.githubusercontent.com/alx9r/BootstraPS/28cbeb78ea2e478889717e741dc12fdceb68ab48/BootstraPS.ps1 -OutFile $_ |
            Out-Null
        $_
        Remove-Item $_
    } |
    % {
        Get-FileHash $_ -Algorithm SHA512 |
            ? {$_.Hash -ne 'E6302F8FA5AD329DFAE397584630441B0B8AF5D1547CD62BE895BBDFD8EB6A3379C863CD95722C8FD03DF75117FB56A810125CA89E2AACFA7756919C0AD354AA' } | 
            % { throw 'Failed hash check.' }
        $_ | Get-Item | Get-Content -Raw | Invoke-Expression
    }
```

Note that the SHA512 hash of the file is checked prior to the call to `Invoke-Expression` to confirm that the download is authentic.

Once Bootstraps is in-memory you can import modules directly from, for example, github.com:

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

`Datum` is still under development and has not incremented its version number (at the time this is being written).  `powershell-yaml` has been released (it can be found using `Found-Module`) but it is difficult to be correlate the revision that you get using `Find-Module` with source code because the `powershell-yaml` project doesn't seem to use github releases or otherwise publish metadata that would make such correlation obvious.  

The absence of official releases or metadata to correlate releases with source code seems to be commonplace for PowerShell modules, in particular for those under active development.  To sidestep these problems we use `Uri`s for archives containing the particular revision.  Because github automatically makes these available, using `Import-WebModule` does not depend on each project's release management practices to deploy the revision of module we need.

## Commands

BootstraPS exports the following commands:

### `Import-WebModule`

```

NAME
    Import-WebModule
    
SYNOPSIS
    Imports a module from the web.
    
    
SYNTAX
    Import-WebModule [-Uri] <Uri> [[-ManifestFileFilter] <String>] [-PassThru] 
    [<CommonParameters>]
    
    Import-WebModule -ModuleSpec <ModuleSpecification> [-SourceLookup] 
    <Hashtable> [-PassThru] [<CommonParameters>]
    
    
DESCRIPTION
    Import-WebModule downloads and imports a module and, optionally, the 
    required modules mentioned in the module's manifest.  Import-WebModule 
    works with a module if it meets the following criteria:
     - has a module manifest
     - is otherwise a well-formed PowerShell module
     - is compressed into a single archive file with the .zip extension
    
    If Import-WebModule encounters a module that requires another module and 
    SourceLookup is provided, Import-WebModule recursively downloads and 
    imports the required modules.
    
    Import-WebModule downloads and expands modules to temporary locations.  
    Import-WebModule deletes the archives immediately after download.  
    Import-WebModule attempts to delete the files of the expanded module 
    immediately after import but will silently leave them behind if that is not 
    possible.  This can occur, for example, when the module contains an 
    assembly that becomes locked when the module is loaded.
    



-ModuleSpec <ModuleSpecification>
    The module specification used to select the Uri from SourceLookup.
    
    Required?                    true
    Position?                    named
    Default value                
    Accept pipeline input?       true (ByValue)
    Accept wildcard characters?  false
    

-SourceLookup <Hashtable>
    A hashtable used by Import-WebModule to lookup the Uri and 
    ManifestFileFilter for a module.
    
    I must be possible to convert each key of SourceLookup to ModuleSpec.
    
    Values of SourceLookup must either be convertible to Uri or a hashtable 
    containing two entries: Uri and ManifestFileFilter.  When importing a 
    module that requires other modules, SourceLookup should include a key value 
    pair for each module that is required.
    
    Required?                    true
    Position?                    2
    Default value                
    Accept pipeline input?       false
    Accept wildcard characters?  false
    

-Uri <Uri>
    The Uri from which to download the module.
    
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
    

-PassThru [<SwitchParameter>]
    Returns the object output by the calls to Import-Module -PassThru. By 
    default, this cmdlet does not generate any output.
    
    Required?                    false
    Position?                    named
    Default value                False
    Accept pipeline input?       false
    Accept wildcard characters?  false
    





```
