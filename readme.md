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

## Commands

BootstraPS exports the following commands:

### `Import-WebModule`

```
NAME
    Import-WebModule
    
SYNOPSIS
    Imports a module from the web.
    
    
SYNTAX
    Import-WebModule [-Uri] <Uri> [<CommonParameters>]
    
    Import-WebModule -ModuleSpec <ModuleSpecification> [-SourceLookup] <Hashtable> 
    [<CommonParameters>]
    
    
DESCRIPTION
    Import-WebModule downloads and imports a module and, optionally, the required 
    modules mentioned in the module's manifest.  Import-WebModule works with modules 
    that meet the following criteria:
     - have module manifest
     - are otherwise well-formed PowerShell modules
     - is compressed into a single archive file with the .zip extension
    
    Import-WebModule encounters a module that requires another module and SourceLookup 
    is provided, Import-WebModule recursively downloads and imports the required 
    modules.
    
    Modules are downloaded to a temporary location and deleted immediately after 
    import.
```