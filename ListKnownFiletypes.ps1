# Script: Get-AllFileExtensionHandlers.ps1
# Purpose: Enumerate all registered file extensions and their handlers
# Output: CSV file with complete extension mapping
# Author: Assistant
# Date: 2024-12-04

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [String]$OutputFile = "AllFileExtensionHandlers_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv"
)

function Get-ExtensionDetails {
    param(
        [Parameter(Mandatory=$true)]
        [String]$Extension,
        
        [Parameter(Mandatory=$true)]
        [Microsoft.Win32.RegistryKey]$ExtensionKey
    )
    
    try {
        $defaultHandler = $ExtensionKey.GetValue('')
        $contentType = $ExtensionKey.GetValue('Content Type')
        $perceivedType = $ExtensionKey.GetValue('PerceivedType')
        $handlerCommand = $null

        if ($defaultHandler) {
            try {
                $handlerPath = "Registry::HKEY_CLASSES_ROOT\$defaultHandler\shell\open\command"
                $handlerCommand = (Get-ItemProperty -Path $handlerPath -ErrorAction Stop).'(Default)'
            }
            catch {
                $handlerCommand = "Handler registered but no open command found"
            }
        }

        return [PSCustomObject]@{
            Extension = $Extension.TrimStart('.')
            IsRegistered = [bool]$defaultHandler
            Handler = $defaultHandler
            Command = $handlerCommand
            ContentType = $contentType
            PerceivedType = $perceivedType
            ErrorMessage = $null
        }
    }
    catch {
        return [PSCustomObject]@{
            Extension = $Extension.TrimStart('.')
            IsRegistered = $false
            Handler = $null
            Command = $null
            ContentType = $null
            PerceivedType = $null
            ErrorMessage = $_.Exception.Message
        }
    }
}

try {
    Write-Host "Starting enumeration of file extensions..." -ForegroundColor Cyan
    $results = @()
    $classesRoot = [Microsoft.Win32.Registry]::ClassesRoot
    
    # Get all subkeys that start with a dot (these are file extensions)
    $extensions = $classesRoot.GetSubKeyNames() | 
                 Where-Object { $_.StartsWith('.') } |
                 Sort-Object
    
    $total = $extensions.Count
    $current = 0
    
    Write-Host "Found $total file extensions to process" -ForegroundColor Green
    
    foreach ($ext in $extensions) {
        $current++
        Write-Progress -Activity "Processing File Extensions" `
                      -Status "Checking: $ext ($current of $total)" `
                      -PercentComplete (($current / $total) * 100)
        
        Write-Verbose "Processing extension: $ext"
        
        try {
            $extKey = $classesRoot.OpenSubKey($ext)
            if ($extKey) {
                $result = Get-ExtensionDetails -Extension $ext -ExtensionKey $extKey
                $results += $result
                $extKey.Close()
            }
        }
        catch {
            Write-Warning "Error processing $ext : $_"
        }
    }

    # Export to CSV
    $results | Export-Csv -Path $OutputFile -NoTypeInformation -Encoding UTF8
    
    Write-Host "`nResults exported to: $OutputFile" -ForegroundColor Green
    
    # Display statistics
    $registered = ($results | Where-Object { $_.IsRegistered -eq $true }).Count
    $unregistered = $total - $registered
    
    Write-Host "`nStatistics:" -ForegroundColor Cyan
    Write-Host "Total extensions found: $total" -ForegroundColor White
    Write-Host "Registered handlers: $registered" -ForegroundColor Green
    Write-Host "Unregistered extensions: $unregistered" -ForegroundColor Yellow
    
    # Display top handlers
    Write-Host "`nTop 10 Handlers:" -ForegroundColor Cyan
    $results | 
        Where-Object { $_.IsRegistered -eq $true } |
        Group-Object Handler |
        Sort-Object Count -Descending |
        Select-Object -First 10 |
        ForEach-Object {
            Write-Host "$($_.Name): $($_.Count) extension(s)" -ForegroundColor Yellow
        }
    
    # Display top content types
    Write-Host "`nTop 10 Content Types:" -ForegroundColor Cyan
    $results | 
        Where-Object { $_.ContentType } |
        Group-Object ContentType |
        Sort-Object Count -Descending |
        Select-Object -First 10 |
        ForEach-Object {
            Write-Host "$($_.Name): $($_.Count) extension(s)" -ForegroundColor Yellow
        }
    
    # Display perceived types distribution
    Write-Host "`nPerceived Types Distribution:" -ForegroundColor Cyan
    $results | 
        Where-Object { $_.PerceivedType } |
        Group-Object PerceivedType |
        Sort-Object Count -Descending |
        ForEach-Object {
            Write-Host "$($_.Name): $($_.Count) extension(s)" -ForegroundColor Yellow
        }
}
catch {
    Write-Error "Critical error: $_"
    exit 1
}
finally {
    Write-Progress -Activity "Processing File Extensions" -Completed
}