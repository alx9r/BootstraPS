
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
	
	Import-WebModule downloads and expands modules to temporary locations and deletes them immediately after import.
	
	.PARAMETER Uri
	The Uri from which to download the module.
	
	.PARAMETER ModuleSpec
	The module specification used to select the Uri from SourceLookup.
    
	.PARAMETER SourceLookup
	A hashtable with keys that can be converted to ModuleSpec and values that are the Uri's corresponding to the location from which each ModuleSpec can be downloaded.  When importing a module that requires other modules, SourceLookup should include a key value pair for each module that is required.
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
        $Uri
    )
    begin
    {
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
                $uri = [uri]($SourceLookup.$match)
                Write-Verbose "Found source $uri for module $ModuleSpec."
                try
                {
                    $uri
                }
                catch
                {
                    throw [System.Exception]::new(
                        ("Uri: $uri",
                        "Module Spec: $ModuleSpec" -join [System.Environment]::NewLine),
                        $_.Exception
                    )
                }
            }
        }

        function Assert-Https
        {
            param
            (
                [Parameter(ValueFromPipeline,
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
                [Parameter(ValueFromPipelineByPropertyName,
                           Mandatory)]
                [string]
                [Alias('FullName')]
                $Path
            )
            process
            {
                $manifestFile = $Path | Get-ChildItem -Filter *.psd1 -Recurse
                $count = $manifestFile | measure | % Count
                if ( $count -gt 1 )
                {
                    throw "Found more than one manifest file in the folder tree rooted at $Path."
                }
                if ( $count -lt 1 )
                {
                    throw "Did not find a manifest file in the folder tree rooted at $Path."
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
        & @{
            hashtable = { $ModuleSpec | Find-WebModuleSource $SourceLookup }
            Uri = { $Uri }
        }.($PSCmdlet.ParameterSetName) |
            Assert-Https |
            Save-WebModule |
            % {
                $_ | Expand-WebModule
                Write-Verbose "Removing item at $_"
                $_ | Remove-Item
            } |
            % {
                $_ |
                    Find-ManifestFile |
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
                Write-Verbose "Removing item at $_"
                $_ | Remove-Item -Recurse
            }
    }
}