<#
.SYNOPSIS
    Creates a file of specified size with either random or custom content.

.DESCRIPTION
    This script creates a file with a specified size, allowing for either binary or text content.
    The content can be random characters or custom text that repeats to fill the file.
    For text files, random content uses ASCII printable characters (32-126).
    For binary files, random content uses the full Unicode range (excluding surrogate pairs).

.PARAMETER Size
    Required. The size of the file to create. 
    Format: number followed by optional KB, MB, or GB suffix.
    Examples: 100, 50KB, 2MB, 1GB

.PARAMETER Type
    Optional. The type of file to create. 
    Valid values: "binary" or "text"
    Default: "binary"

.PARAMETER FilePath
    Optional. The path and name of the file to create.
    If not specified, generates name: <hostname>-<timestamp>-<guid>.<extension>
    Default: Generated in current directory

.PARAMETER Content
    Optional. The content to write to the file.
    Use "random" for random characters, or specify text in quotes for repeated content.
    Default: "random"

.EXAMPLE
    .\Create-File.ps1 1MB
    Creates a 1MB binary file with random Unicode characters

.EXAMPLE
    .\Create-File.ps1 50KB text
    Creates a 50KB text file with random ASCII characters

.EXAMPLE
    .\Create-File.ps1 1MB text -Content "Hello World! "
    Creates a 1MB text file filled with repeated "Hello World! "

.EXAMPLE
    .\Create-File.ps1 100KB text C:\temp\custom.txt "Custom text"
    Creates a 100KB text file at specified path with repeated custom text

.NOTES
    Author: [Your Name]
    Date: [Current Date]
    Version: 1.0
#>

[CmdletBinding()]
param(
    # Size parameter - required, accepts number with optional suffix
    [Parameter(Mandatory=$true, Position=0)]
    [string]$Size,
    
    # Type parameter - optional, validates against set
    [Parameter(Mandatory=$false, Position=1)]
    [ValidateSet("binary", "text")]
    [string]$Type = "binary",
    
    # FilePath parameter - optional, default is generated
    [Parameter(Mandatory=$false, Position=2)]
    [string]$FilePath = "",

    # Content parameter - optional, default is random
    [Parameter(Mandatory=$false, Position=3)]
    [string]$Content = "random"
)

# Function to convert size string (e.g., "1MB") to bytes
function Convert-ToBytes {
    param([string]$SizeString)
    
    # Regular expression to match number and optional suffix
    if ($SizeString -match "^(\d+)(KB|MB|GB)?$") {
        $number = [Int64]$Matches[1]
        $unit = $Matches[2]
        
        # Convert based on suffix (KB, MB, GB)
        switch ($unit) {
            "KB" { return $number * 1024 }        # Kilobytes
            "MB" { return $number * 1024 * 1024 } # Megabytes
            "GB" { return $number * 1024 * 1024 * 1024 } # Gigabytes
            default { return $number }            # Bytes if no suffix
        }
    }
    else {
        throw "Invalid size format. Use number followed by KB, MB, or GB (e.g., 10MB)"
    }
}

# Function to generate random content based on file type
function Get-RandomContent {
    param(
        [bool]$IsText,      # True for text file, False for binary
        [int]$Length        # Number of characters to generate
    )
    
    if ($IsText) {
        # For text files: use ASCII printable characters (32-126)
        # This includes letters, numbers, and common punctuation
        $chars = [char[]] (32..126)
        return -join ((1..$Length) | ForEach-Object { $chars | Get-Random })
    }
    else {
        # For binary files: use full Unicode range
        # Exclude surrogate pairs (0xD800-0xDFFF) to avoid invalid characters
        $chars = [char[]] ((0..0xD7FF) + (0xE000..0xFFFF))
        return -join ((1..$Length) | ForEach-Object { $chars | Get-Random })
    }
}

# Generate default filename if not provided
if ([string]::IsNullOrEmpty($FilePath)) {
    $extension = if ($Type -eq "binary") { "bin" } else { "txt" }
    $timestamp = Get-Date -Format "yyyy-MM-ddTHH-mm-ss"
    $hostname = [System.Environment]::MachineName
    $guid = [System.Guid]::NewGuid().ToString()
    $FilePath = "${hostname}-${timestamp}-${guid}.${extension}"
}

try {
    # Convert size specification to bytes
    $sizeInBytes = Convert-ToBytes $Size
    
    Write-Verbose "Creating $Type file of size $sizeInBytes bytes at $FilePath"
    
    # Create StreamWriter for efficient file writing
    $stream = [System.IO.StreamWriter]::new($FilePath)
    $bytesWritten = 0
    $bufferSize = 1MB  # Write in 1MB chunks for efficiency
    
    if ($Content -eq "random") {
        # Generate and write random content in chunks
        while ($bytesWritten -lt $sizeInBytes) {
            $remainingBytes = $sizeInBytes - $bytesWritten
            $chunkSize = [Math]::Min($bufferSize, $remainingBytes)
            $chunk = Get-RandomContent -IsText ($Type -eq "text") -Length $chunkSize
            $stream.Write($chunk)
            $bytesWritten += [System.Text.Encoding]::UTF8.GetByteCount($chunk)
        }
    }
    else {
        # Repeat specified content until desired size is reached
        while ($bytesWritten -lt $sizeInBytes) {
            $stream.Write($Content)
            $bytesWritten += [System.Text.Encoding]::UTF8.GetByteCount($Content)
        }
    }
    
    # Close the stream to flush buffer and release resources
    $stream.Close()
    
    # Trim file to exact size if we wrote too much
    if ($bytesWritten -gt $sizeInBytes) {
        $bytes = [System.IO.File]::ReadAllBytes($FilePath)
        [System.IO.File]::WriteAllBytes($FilePath, $bytes[0..($sizeInBytes-1)])
    }
    
    # Report results
    Write-Host "Created file: $FilePath"
    Write-Host "Actual size: $((Get-Item $FilePath).Length) bytes"
}
catch {
    Write-Error "Error creating file: $_"
    exit 1
}

