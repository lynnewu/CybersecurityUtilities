# Define root, SBOM, and report output folders with timestamp
$timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
$sourceRoot = "C:\src"
$sbomDir = "C:\sboms\$timestamp"
$reportDir = "C:\sboms\$timestamp\reports"
$consolidatedReport = "C:\sboms\consolidated-vulnerabilities_$timestamp.csv"

# Parallelization settings
$maxConcurrentJobs = 8
$syftParallelism = 4

Write-Host "Scan timestamp: $timestamp"
Write-Host "Output directory: C:\sboms\$timestamp"

# Validate source directory exists
if (-not (Test-Path $sourceRoot)) {
    Write-Error "Source directory does not exist: $sourceRoot"
    exit 1
}

# Check for required tools
$tools = @('syft', 'grype')
foreach ($tool in $tools) {
    try {
        & $tool --version | Out-Null
    }
    catch {
        Write-Error "Required tool '$tool' not found in PATH or not working"
        exit 1
    }
}

# Ensure output folders exist
New-Item -ItemType Directory -Force -Path $sbomDir | Out-Null
New-Item -ItemType Directory -Force -Path $reportDir | Out-Null

# Find all .csproj files recursively
$projects = Get-ChildItem -Path $sourceRoot -Recurse -Filter *.csproj

if ($projects.Count -eq 0) {
    Write-Warning "No .csproj files found in $sourceRoot"
    exit 0
}

Write-Host "Found $($projects.Count) projects to scan with $maxConcurrentJobs concurrent jobs..."

# Script block for processing each project
$scriptBlock = {
    param($projPath, $projDir, $projName, $sourceRoot, $sbomDir, $reportDir, $syftParallelism, $timestamp)
    
    # Calculate relative path
    $relativePath = $projDir -replace [regex]::Escape($sourceRoot), ""
    $relativePath = $relativePath.TrimStart('\')
    
    $sanitizedName = $projName -replace '[^a-zA-Z0-9\-_]', '_'
    $sbomPath = Join-Path $sbomDir "$sanitizedName-sbom_$timestamp.json"
    $jsonReportPath = Join-Path $reportDir "$sanitizedName-grype_$timestamp.json"
    
    $result = @{
        Project = $projName
        ProjectPath = $relativePath
        FullPath = $projDir
        Success = $false
        Error = $null
        VulnerabilityCount = 0
        Vulnerabilities = @()
        SbomPath = $sbomPath
        ReportPath = $jsonReportPath
    }
    
    try {
        # Generate SBOM with parallelism
        & syft "$projDir" --source-name "$projName" --parallelism $syftParallelism --output "cyclonedx-json=$sbomPath" 2>$null
        
        if (-not (Test-Path $sbomPath)) {
            $result.Error = "SBOM file was not created"
            return $result
        }
        
        # Run Grype scan
        & grype "$sbomPath" --output "json=$jsonReportPath" 2>$null
        
        if (-not (Test-Path $jsonReportPath)) {
            $result.Error = "Grype report not created"
            return $result
        }
        
        # Parse JSON and extract vulnerabilities
        try {
            $jsonContent = Get-Content $jsonReportPath -Raw | ConvertFrom-Json
            
            if ($jsonContent.matches -and $jsonContent.matches.Count -gt 0) {
                $result.VulnerabilityCount = $jsonContent.matches.Count
                
                foreach ($match in $jsonContent.matches) {
                    $vulnerability = [PSCustomObject]@{
                        Project = $projName
                        ProjectPath = $relativePath
                        FullPath = $projDir
                        Package = $match.artifact.name
                        PackageVersion = $match.artifact.version
                        PackageType = $match.artifact.type
                        VulnerabilityID = $match.vulnerability.id
                        Severity = $match.vulnerability.severity
                        Description = ($match.vulnerability.description -replace "`n|`r", " ").Substring(0, [Math]::Min(200, $match.vulnerability.description.Length))
                        FixedInVersion = if ($match.vulnerability.fix.versions) { $match.vulnerability.fix.versions -join ", " } else { "N/A" }
                        CVSS = if ($match.vulnerability.cvss) { 
                            $cvssScores = @()
                            foreach ($cvss in $match.vulnerability.cvss) {
                                if ($cvss.metrics.baseScore) {
                                    $cvssScores += "$($cvss.version): $($cvss.metrics.baseScore)"
                                }
                            }
                            $cvssScores -join "; "
                        } else { "N/A" }
                        References = if ($match.vulnerability.urls) { $match.vulnerability.urls -join "; " } else { "N/A" }
                        ScanDate = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
                        ScanTimestamp = $timestamp
                    }
                    
                    $result.Vulnerabilities += $vulnerability
                }
                
                $result.Success = $true
            } else {
                $result.Success = $true
                $result.VulnerabilityCount = 0
            }
        } catch {
            $result.Error = "Could not parse JSON report: $($_.Exception.Message)"
        }
        
    } catch {
        $result.Error = "Failed to scan project: $($_.Exception.Message)"
    }
    
    return $result
}

# Record start time
$startTime = Get-Date

# Process projects with job throttling
$jobs = @()
$allVulnerabilities = @()
$completedCount = 0
$totalProjects = $projects.Count

foreach ($proj in $projects) {
    # Wait if we've reached the maximum number of concurrent jobs
    while ((Get-Job -State Running).Count -ge $maxConcurrentJobs) {
        Start-Sleep -Milliseconds 500
        
        # Check for completed jobs
        $completedJobs = Get-Job -State Completed
        foreach ($job in $completedJobs) {
            $jobResult = Receive-Job -Job $job
            Remove-Job -Job $job
            
            $completedCount++
            
            if ($jobResult.Success) {
                if ($jobResult.VulnerabilityCount -gt 0) {
                    Write-Host "[$completedCount/$totalProjects] $($jobResult.Project): $($jobResult.VulnerabilityCount) vulnerabilities found"
                    $allVulnerabilities += $jobResult.Vulnerabilities
                } else {
                    Write-Host "[$completedCount/$totalProjects] $($jobResult.Project): No vulnerabilities found"
                }
            } else {
                Write-Warning "[$completedCount/$totalProjects] $($jobResult.Project): $($jobResult.Error)"
            }
        }
    }
    
    # Start new job
    $projDir = $proj.Directory.FullName
    $projName = $proj.BaseName
    
    Write-Host "Starting scan for: $projName"
    $job = Start-Job -ScriptBlock $scriptBlock -ArgumentList @($proj.FullName, $projDir, $projName, $sourceRoot, $sbomDir, $reportDir, $syftParallelism, $timestamp)
    $jobs += $job
}

# Wait for all remaining jobs to complete
Write-Host "`nWaiting for remaining jobs to complete..."
while ((Get-Job -State Running).Count -gt 0) {
    Start-Sleep -Milliseconds 500
    
    # Process completed jobs
    $completedJobs = Get-Job -State Completed
    foreach ($job in $completedJobs) {
        $jobResult = Receive-Job -Job $job
        Remove-Job -Job $job
        
        $completedCount++
        
        if ($jobResult.Success) {
            if ($jobResult.VulnerabilityCount -gt 0) {
                Write-Host "[$completedCount/$totalProjects] $($jobResult.Project): $($jobResult.VulnerabilityCount) vulnerabilities found"
                $allVulnerabilities += $jobResult.Vulnerabilities
            } else {
                Write-Host "[$completedCount/$totalProjects] $($jobResult.Project): No vulnerabilities found"
            }
        } else {
            Write-Warning "[$completedCount/$totalProjects] $($jobResult.Project): $($jobResult.Error)"
        }
    }
}

# Clean up any remaining jobs
Get-Job | Remove-Job -Force

# Export consolidated report
Write-Host "`nGenerating consolidated CSV report..."

if ($allVulnerabilities.Count -gt 0) {
    $allVulnerabilities | Export-Csv -Path $consolidatedReport -NoTypeInformation -Encoding UTF8
    
    Write-Host "Consolidated report saved to: $consolidatedReport"
    Write-Host "Total vulnerabilities found: $($allVulnerabilities.Count)"
    
    # Summary by severity
    $severitySummary = $allVulnerabilities | Group-Object Severity | Sort-Object Name
    Write-Host "`nVulnerabilities by severity:"
    foreach ($severity in $severitySummary) {
        Write-Host "  $($severity.Name): $($severity.Count)"
    }
    
    # Summary by project
    $projectSummary = $allVulnerabilities | Group-Object Project | Sort-Object Count -Descending
    Write-Host "`nTop projects by vulnerability count:"
    $projectSummary | Select-Object -First 10 | ForEach-Object {
        Write-Host "  $($_.Name): $($_.Count) vulnerabilities"
    }
    
    # Create scan summary file
    $summaryFile = "C:\sboms\scan-summary_$timestamp.txt"
    $summary = @"
Vulnerability Scan Summary
Timestamp: $timestamp
Scan Duration: $((Get-Date) - $startTime)
Projects Scanned: $totalProjects
Total Vulnerabilities: $($allVulnerabilities.Count)
Concurrent Jobs: $maxConcurrentJobs
Syft Parallelism: $syftParallelism

Vulnerabilities by Severity:
$($severitySummary | ForEach-Object { "  $($_.Name): $($_.Count)" } | Out-String)

Top Projects by Vulnerability Count:
$($projectSummary | Select-Object -First 10 | ForEach-Object { "  $($_.Name): $($_.Count)" } | Out-String)

Files Generated:
- Consolidated CSV: $consolidatedReport
- Individual SBOMs: $sbomDir
- Individual Reports: $reportDir
"@
    
    $summary | Out-File -FilePath $summaryFile -Encoding UTF8
    Write-Host "Scan summary saved to: $summaryFile"
    
} else {
    Write-Host "No vulnerabilities found across all projects."
    # Still create an empty CSV with headers
    [PSCustomObject]@{
        Project = ""
        ProjectPath = ""
        FullPath = ""
        Package = ""
        PackageVersion = ""
        PackageType = ""
        VulnerabilityID = ""
        Severity = ""
        Description = ""
        FixedInVersion = ""
        CVSS = ""
        References = ""
        ScanDate = ""
        ScanTimestamp = ""
    } | Export-Csv -Path $consolidatedReport -NoTypeInformation -Encoding UTF8
    
    # Remove the empty row
    $content = Get-Content $consolidatedReport
    $content[0] | Set-Content $consolidatedReport
}

$endTime = Get-Date
$duration = $endTime - $startTime

Write-Host "`n=== Scan Completed ==="
Write-Host "Timestamp: $timestamp"
Write-Host "Duration: $duration"
Write-Host "Individual SBOMs: $sbomDir"
Write-Host "Individual reports: $reportDir"
Write-Host "Consolidated CSV: $consolidatedReport"