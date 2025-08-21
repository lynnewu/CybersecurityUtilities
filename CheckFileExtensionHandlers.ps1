# Script: Check-FileExtensionHandlers.ps1
# Purpose: Read file extensions (without dots) and check if they have registered handlers
# Output: CSV file with results
# Author: Assistant
# Date: 2024-12-04

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [String]$InputFile,
    
    [Parameter(Mandatory=$false)]
    [String]$OutputFile = "FileExtensionHandlers_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv"
)

function Get-FileAssociation {
    param(
        [Parameter(Mandatory=$true)]
        [String]$Extension
    )
    
    try {
        # Remove any dots if they exist and add a single dot
        $Extension = "." + $Extension.TrimStart('.')
        
        # Get registry information for the extension
        $registryPath = "Registry::HKEY_CLASSES_ROOT\$Extension"
        $defaultHandler = (Get-ItemProperty -Path $registryPath -ErrorAction Stop).'(Default)'
        
        # If we have a default handler, try to get more details
        if ($defaultHandler) {
            $handlerPath = "Registry::HKEY_CLASSES_ROOT\$defaultHandler\shell\open\command"
            $handlerCommand = $null
            $contentType = $null
            $perceivedType = $null
            
            try {
                # Try to get additional properties
                $extProps = Get-ItemProperty -Path $registryPath -ErrorAction SilentlyContinue
                $contentType = $extProps.ContentType
                $perceivedType = $extProps.PerceivedType
                
                $handlerCommand = (Get-ItemProperty -Path $handlerPath -ErrorAction Stop).'(Default)'
            }
            catch {
                $handlerCommand = "Handler registered but no open command found"
            }

            return [PSCustomObject]@{
                Extension = $Extension.TrimStart('.')  # Remove dot for consistency
                IsRegistered = $true
                Handler = $defaultHandler
                Command = $handlerCommand
                ContentType = $contentType
                PerceivedType = $perceivedType
                ErrorMessage = $null
            }
        }
        else {
            return [PSCustomObject]@{
                Extension = $Extension.TrimStart('.')
                IsRegistered = $false
                Handler = $null
                Command = $null
                ContentType = $null
                PerceivedType = $null
                ErrorMessage = "No handler registered"
            }
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

# Verify input file exists
if (-not (Test-Path $InputFile)) {
    Write-Error "Input file not found: $InputFile"
    exit 1
}

try {
    # Create array to hold results
    $results = @()
    
    # Read extensions and process them
    $extensions = Get-Content $InputFile -ErrorAction Stop | 
                 Where-Object { -not [String]::IsNullOrWhiteSpace($_) } |
                 ForEach-Object { $_.Trim() }

    $total = $extensions.Count
    $current = 0

    foreach ($ext in $extensions) {
        $current++
        Write-Progress -Activity "Processing File Extensions" -Status "Checking: $ext" `
                      -PercentComplete (($current / $total) * 100)
        
        Write-Verbose "Processing extension: $ext"
        $result = Get-FileAssociation -Extension $ext
        $results += $result
    }

    # Export to CSV
    $results | Export-Csv -Path $OutputFile -NoTypeInformation -Encoding UTF8
    
    Write-Host "Results exported to: $OutputFile" -ForegroundColor Green
    
    # Display quick summary
    $total = $results.Count
    $registered = ($results | Where-Object { $_.IsRegistered -eq $true }).Count
    $unregistered = $total - $registered
    
    Write-Host "`nSummary:" -ForegroundColor Cyan
    Write-Host "Total extensions processed: $total" -ForegroundColor White
    Write-Host "Registered handlers found: $registered" -ForegroundColor Green
    Write-Host "Unregistered extensions: $unregistered" -ForegroundColor Yellow

    # Display top handlers (useful for analysis)
    Write-Host "`nTop Handlers:" -ForegroundColor Cyan
    $results | 
        Where-Object { $_.IsRegistered -eq $true } |
        Group-Object Handler |
        Sort-Object Count -Descending |
        Select-Object -First 5 |
        ForEach-Object {
            Write-Host "$($_.Name): $($_.Count) extension(s)" -ForegroundColor Yellow
        }
}
catch {
    Write-Error "Error processing file: $_"
    exit 1
}
finally {
    Write-Progress -Activity "Processing File Extensions" -Completed
}