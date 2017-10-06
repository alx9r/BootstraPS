
#Requires -Version 5

function Import-WebModule
{
    <#
	.SYNOPSIS
	Imports a module from the web.

	.DESCRIPTION
	Import-WebModule downloads and imports a module and, optionally, the required modules mentioned in the module's manifest.  Import-WebModule works with a module if it meets the following criteria:
	 - has a module manifest
	 - is otherwise a well-formed PowerShell module
	 - is compressed into a single archive file with the .zip extension
	
	If Import-WebModule encounters a module that requires another module and SourceLookup is provided, Import-WebModule recursively downloads and imports the required modules.
	
	Import-WebModule downloads and expands modules to temporary locations.  Import-WebModule deletes the archives immediately after download.  Import-WebModule attempts to delete the files of the expanded module immediately after import but will silently leave them behind if that is not possible.  This can occur, for example, when the module contains an assembly that becomes locked when the module is loaded.
	
	.PARAMETER Uri
	The Uri from which to download the module.
	
	.PARAMETER ModuleSpec
	The module specification used to select the Uri from SourceLookup.
    
	.PARAMETER SourceLookup
	A hashtable used by Import-WebModule to lookup the Uri and ManifestFileFilter for a module.
	
	I must be possible to convert each key of SourceLookup to ModuleSpec.

	Values of SourceLookup must either be convertible to Uri or a hashtable containing two entries: Uri and ManifestFileFilter.  When importing a module that requires other modules, SourceLookup should include a key value pair for each module that is required.

    .PARAMETER ManifestFileFilter
	A filter passed by Import-WebModule to Get-ChildItem to select the manifest file for the module.

    #>
    [CmdletBinding(DefaultParameterSetName = 'Uri')]
    param
    (
        [Parameter(ParameterSetName = 'hashtable',
                   ValueFromPipeline,
                   Mandatory)]
        [Microsoft.PowerShell.Commands.ModuleSpecification]
        $ModuleSpec,

        [Parameter(ParameterSetName = 'hashtable',
                   Position = 1,
                   Mandatory)]
        [hashtable]
        $SourceLookup,

        [Parameter(ParameterSetName = 'Uri',
                   Position = 1,
                   Mandatory)]
        [Uri]
        $Uri,

        [Parameter(ParameterSetName = 'Uri',
                   Position = 2)]
        [string]
        $ManifestFileFilter = '*.psd1'
    )
    begin
    {
        $defaultManifestFileFilter = '*.psd1'
        
        function Find-WebModuleSource
        {
            param
            (
                [Parameter(ValueFromPipeline,
                           Mandatory)]
                [Microsoft.PowerShell.Commands.ModuleSpecification]
                $ModuleSpec,

                [Parameter(Position = 1,
                           Mandatory)]
                [hashtable]
                $SourceLookup
            )
            process
            {
                $match = $SourceLookup.Keys |
                    ? {
                        $lookupSpec = [Microsoft.PowerShell.Commands.ModuleSpecification]$_
                        if ($lookupSpec.Name -eq $ModuleSpec.Name)
                        {
                            if ( $ModuleSpec.Version )
                            {
                                $lookupSpec.Version -eq $ModuleSpec.Version
                            }
                            else
                            {
                                $true
                            }
                        }
                    }
                $count = $match | measure | % Count
                if ( $count -gt 1 )
                {
                    throw "Found more than one match for module specification $ModuleSpec in SourceLookup."
                }
                if ( $count -lt 1 )
                {
                    throw "Did not find a match module specification $ModuleSpec in SourceLookup."
                }
                $entry = $SourceLookup.$match
                Write-Verbose "Found source entry $entry for module $ModuleSpec."
                try
                {
                    $entry
                }
                catch
                {
                    throw [System.Exception]::new(
                        "Module Spec: $ModuleSpec",
                        $_.Exception
                    )
                }
            }
        }

        function ConvertTo-WebModuleSourceArgs
        {
            param
            (
                [Parameter(ParameterSetName = 'uri',
                           ValueFromPipeline,
                           Mandatory)]
                [uri]
                $Uri,

                [Parameter(ParameterSetName = 'hashtable',
                           ValueFromPipeline,
                           Mandatory)]
                [hashtable]
                $Hashtable
            )
            process
            {
                if ($PSCmdlet.ParameterSetName -eq 'uri')
                {
                    return [pscustomobject]@{
                        Uri=$Uri
                        ManifestFileFilter = $defaultManifestFileFilter
                    }
                }
                if ( -not $Hashtable.Uri )
                {
                    throw "Hashtable does not contain entry for Uri"
                }
                if ( -not $Hashtable.Manifest -and
                     -not $Hashtable.ManifestFile -and
                     -not $Hashtable.ManifestFileFilter )
                {
                    $Hashtable.ManifestFileFilter = $defaultManifestFileFilter
                }
                [pscustomobject]$Hashtable
            }
        }

        function Assert-Https
        {
            param
            (
                [Parameter(ValueFromPipeline,
                           ValueFromPipelineByPropertyName,
                           Mandatory)]
                [uri]
                $Uri
            )
            process
            {
                if ($Uri.Scheme -ne 'https')
                {
                    throw "Uri $Uri is not https"
                }
                $Uri
            }
        }

        function Save-WebModule
        {
            param
            (
                [Parameter(ValueFromPipeline,
                           Mandatory)]
                [Uri]
                $Uri
            )
            process
            {
                $archivePath = [System.IO.Path]::GetTempPath()+[guid]::NewGuid().Guid+'.zip'
                Write-Verbose "Downloading $Uri to $archivePath..."
                Invoke-WebRequest $Uri -OutFile $archivePath
                Write-Verbose 'Complete.'
                try
                {
                    Get-Item $archivePath -ErrorAction Stop
                }
                catch
                {
                    throw [System.Exception]::new(
                        ("Uri: $Uri",
                         "Archive Path: $archivePath" -join [System.Environment]::NewLine),
                        $_.Exception
                    )
                }
            }
        }

        function Expand-WebModule
        {
            param
            (
                [Parameter(ValueFromPipelineByPropertyName,
                           Mandatory)]
                [string]
                [Alias('FullName')]
                $Path
            )
            process
            {
                $destPath = [System.IO.Path]::GetTempPath()+[guid]::NewGuid().Guid
                Write-Verbose "Expanding archive $Path to $destPath..."
                $Path | Expand-Archive -Dest $destPath -ErrorAction Stop
                Write-Verbose 'Complete.'
                try
                {
                    Get-Item $destPath -ErrorAction Stop
                }
                catch
                {
                    throw [System.Exception]::new(
                        ("Source path (Path): $ $Path",
                         "Dest path: $destPath" -join [System.Environment]::NewLine),
                        $_.Exception
                    )
                }
            }
        }

        function Find-ManifestFile
        {
            param
            (
                [Parameter(Position = 1,
                           Mandatory)]
                [string]
                $Path,

                [Parameter(ValueFromPipelineByPropertyName,
                           Mandatory)]
                [Alias('Manifest')]
                [Alias('ManifestFile')]
                [Alias('ManifestFileFilter')]
                $Filter
            )
            process
            {
                $manifestFile = $Path | Get-ChildItem -Filter $Filter -Recurse -File
                $count = $manifestFile | measure | % Count
                if ( $count -gt 1 )
                {
                    throw "Found more than one manifest file matched filter $Filter in the folder tree rooted at $Path : $($manifestFile.Name)"
                }
                if ( $count -lt 1 )
                {
                    throw "Did not find a manifest file matching filter $Filter the folder tree rooted at $Path."
                }
                Write-Verbose "Found manifest file $Path."
                try
                {
                    $manifestFile
                }
                catch
                {
                    throw [System.Exception]::new(
                        "Manifest Path: $($manifest.FullName)",
                        $_.Exception
                    )
                }
            }
        }

        function Get-RequiredModule
        {
            param
            (
                [Parameter(ValueFromPipelineByPropertyName,
                           Mandatory)]
                [string]
                [Alias('FullName')]
                $Path
            )
            process
            {
                if ( $Path -notmatch '\.psd1$' )
                {
                    throw "$Path does not have the .psd1 extension."
                }
                Write-Verbose "Retrieving contents of manifest file $Path."
                $contents = Import-PowerShellDataFile $Path -ErrorAction Stop

                foreach ( $requiredModule in $contents.RequiredModules )
                {
                    $moduleSpec = [Microsoft.PowerShell.Commands.ModuleSpecification]$requiredModule
                    Write-Verbose "Found required module $moduleSpec."
                    try
                    {
                        $moduleSpec
                    }
                    catch
                    {
                        throw [System.Exception]::new(
                            "Required Module: $moduleSpec",
                            $_.Exception
                        )
                    }
                }
            }
        }
    }
    process
    {
        if ( $PSCmdlet.ParameterSetName -eq 'Uri' )
        {
            'nameless' | Import-WebModule @{
                nameless = @{
                    Uri = $Uri
                    ManifestFileFilter = $ManifestFileFilter
                }
            }
            return
        }
        $arguments = $ModuleSpec | 
            Find-WebModuleSource $SourceLookup |
            ConvertTo-WebModuleSourceArgs
                        
        $arguments |
            Assert-Https |
            Save-WebModule |
            % {
                $_ | Expand-WebModule
                Write-Verbose "Removing item at $_"
                $_ | Remove-Item
            } |
            % {
                $arguments |
                    Find-ManifestFile $_.FullName |
                    % {
                        $_ |
                            ? { $PSCmdlet.ParameterSetName -eq 'hashtable' } |
                            Get-RequiredModule |
                            % { $_ | Import-WebModule $SourceLookup }
                        $_
                    } |
                    % FullName |
                    % {
                        Write-Verbose "Importing module $_"
                        $_ | Import-Module -ErrorAction Stop
                    }
                Write-Verbose "Attempting to removing item at $_"
                $_ | Remove-Item -Recurse -ErrorAction SilentlyContinue
            }
    }
}