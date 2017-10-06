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
Invoke-WebRequest https://raw.githubusercontent.com/alx9r/BootstraPS/master/BootstraPS.ps1 |
    % Content |
    Invoke-Expression
```

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

This particular revision of `Datum` requires `ProtectedData` version 4.1.0 which requires `powershell-yaml`.    `Import-WebModule` works this out based on each module's module manifest and imports each module as necessary

`Datum` is still under development and does not have an official release (at the time this is being written).  `powershell-yaml` has been released (it can be found using) `Found-Module` but it is difficult to be correlate the revision that you get using `Find-Module` with source code because the `powershell-yaml` project doesn't seem to use github releases or otherwise publish metadata that would make such correlation obvious.  To sidestep these problems we provide `Uri`s to an archive containing the particular revision.  That way we know exactly the revision we are using.  

## Commands

BootstraPS exports the following commands:

### `Import-WebModule`

```
NAME
    Import-WebModule
    
SYNOPSIS
    Imports a module from the web.
    
    
SYNTAX
    Import-WebModule [-Uri] <Uri> [[-ManifestFileFilter] <String>] 
    [<CommonParameters>]
    
    Import-WebModule -ModuleSpec <ModuleSpecification> [-SourceLookup] 
    <Hashtable> [<CommonParameters>]
    
    
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
    immediately after import but will silently leave them behind if that is 
    not possible.  This can occur, for example, when the module contains an 
    assembly that becomes locked when the module is loaded.

```