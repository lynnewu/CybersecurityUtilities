$outputFile = ".\AllWindowsEventIDs_WithCategories.csv"

# Create CSV header
"EventID,Source,Category,Subcategory,Description" | Out-File -FilePath $outputFile -Encoding utf8

Write-Host "Starting collection of event IDs with categories..."

# Define known audit categories and subcategories mapping
$auditCategories = @{
    "Account Logon" = @("Credential Validation", "Kerberos Authentication Service", "Kerberos Service Ticket Operations", "Other Account Logon Events")
    "Account Management" = @("Application Group Management", "Computer Account Management", "Distribution Group Management", "Other Account Management Events", "Security Group Management", "User Account Management")
    "Detailed Tracking" = @("DPAPI Activity", "Process Creation", "Process Termination", "RPC Events")
    "DS Access" = @("Detailed Directory Service Replication", "Directory Service Access", "Directory Service Changes", "Directory Service Replication")
    "Logon/Logoff" = @("Account Lockout", "Group Membership", "IPsec Extended Mode", "IPsec Main Mode", "IPsec Quick Mode", "Logoff", "Logon", "Network Policy Server", "Other Logon/Logoff Events", "Special Logon", "User / Device Claims")
    "Object Access" = @("Application Generated", "Central Access Policy Staging", "Certification Services", "Detailed File Share", "File Share", "File System", "Filtering Platform Connection", "Filtering Platform Packet Drop", "Handle Manipulation", "Kernel Object", "Other Object Access Events", "Registry", "SAM", "Removable Storage")
    "Policy Change" = @("Audit Policy Change", "Authentication Policy Change", "Authorization Policy Change", "Filtering Platform Policy Change", "MPSSVC Rule-Level Policy Change", "Other Policy Change Events")
    "Privilege Use" = @("Non Sensitive Privilege Use", "Other Privilege Use Events", "Sensitive Privilege Use")
    "System" = @("IPsec Driver", "Other System Events", "Security State Change", "Security System Extension", "System Integrity")
}

# Event ID to category mapping based on Microsoft documentation
# This is a partial mapping of well-known security audit event IDs
$eventIDToCategory = @{
    # Account Logon - Credential Validation
    "4774" = @("Account Logon", "Credential Validation")
    "4775" = @("Account Logon", "Credential Validation")
    "4776" = @("Account Logon", "Credential Validation")
    "4777" = @("Account Logon", "Credential Validation")
    
    # Account Logon - Kerberos Authentication Service
    "4768" = @("Account Logon", "Kerberos Authentication Service")
    "4771" = @("Account Logon", "Kerberos Authentication Service")
    "4772" = @("Account Logon", "Kerberos Authentication Service")
    
    # Account Logon - Kerberos Service Ticket Operations
    "4769" = @("Account Logon", "Kerberos Service Ticket Operations")
    "4770" = @("Account Logon", "Kerberos Service Ticket Operations")
    
    # Account Management - User Account Management
    "4720" = @("Account Management", "User Account Management")
    "4722" = @("Account Management", "User Account Management")
    "4723" = @("Account Management", "User Account Management")
    "4724" = @("Account Management", "User Account Management")
    "4725" = @("Account Management", "User Account Management")
    "4726" = @("Account Management", "User Account Management")
    "4738" = @("Account Management", "User Account Management")
    "4740" = @("Account Management", "User Account Management")
    "4767" = @("Account Management", "User Account Management")
    "4780" = @("Account Management", "User Account Management")
    "4781" = @("Account Management", "User Account Management")
    "4794" = @("Account Management", "User Account Management")
    
    # Account Management - Security Group Management
    "4727" = @("Account Management", "Security Group Management")
    "4728" = @("Account Management", "Security Group Management")
    "4729" = @("Account Management", "Security Group Management")
    "4730" = @("Account Management", "Security Group Management")
    "4731" = @("Account Management", "Security Group Management")
    "4732" = @("Account Management", "Security Group Management")
    "4733" = @("Account Management", "Security Group Management")
    "4734" = @("Account Management", "Security Group Management")
    "4735" = @("Account Management", "Security Group Management")
    "4737" = @("Account Management", "Security Group Management")
    "4754" = @("Account Management", "Security Group Management")
    "4755" = @("Account Management", "Security Group Management")
    "4756" = @("Account Management", "Security Group Management")
    "4757" = @("Account Management", "Security Group Management")
    "4758" = @("Account Management", "Security Group Management")
    "4764" = @("Account Management", "Security Group Management")
    
    # Account Management - Computer Account Management
    "4741" = @("Account Management", "Computer Account Management")
    "4742" = @("Account Management", "Computer Account Management")
    "4743" = @("Account Management", "Computer Account Management")
    
    # Detailed Tracking - Process Creation
    "4688" = @("Detailed Tracking", "Process Creation")
    "4696" = @("Detailed Tracking", "Process Creation")
    
    # Detailed Tracking - Process Termination
    "4689" = @("Detailed Tracking", "Process Termination")
    
    # Detailed Tracking - DPAPI Activity
    "4692" = @("Detailed Tracking", "DPAPI Activity")
    "4693" = @("Detailed Tracking", "DPAPI Activity")
    "4694" = @("Detailed Tracking", "DPAPI Activity")
    "4695" = @("Detailed Tracking", "DPAPI Activity")
    
    # Logon/Logoff - Logon
    "4624" = @("Logon/Logoff", "Logon")
    "4625" = @("Logon/Logoff", "Logon")
    "4648" = @("Logon/Logoff", "Logon")
    
    # Logon/Logoff - Logoff
    "4634" = @("Logon/Logoff", "Logoff")
    "4647" = @("Logon/Logoff", "Logoff")
    
    # Logon/Logoff - Special Logon
    "4672" = @("Logon/Logoff", "Special Logon")
    
    # Logon/Logoff - Other Logon/Logoff Events
    "4649" = @("Logon/Logoff", "Other Logon/Logoff Events")
    "4778" = @("Logon/Logoff", "Other Logon/Logoff Events")
    "4779" = @("Logon/Logoff", "Other Logon/Logoff Events")
    "4800" = @("Logon/Logoff", "Other Logon/Logoff Events")
    "4801" = @("Logon/Logoff", "Other Logon/Logoff Events")
    "4802" = @("Logon/Logoff", "Other Logon/Logoff Events")
    "4803" = @("Logon/Logoff", "Other Logon/Logoff Events")
    
    # Object Access - File System
    "4656" = @("Object Access", "File System")
    "4658" = @("Object Access", "File System")
    "4660" = @("Object Access", "File System")
    "4663" = @("Object Access", "File System")
    "4664" = @("Object Access", "File System")
    
    # Object Access - Registry
    "4657" = @("Object Access", "Registry")
    
    # Object Access - Filtering Platform Connection
    "5156" = @("Object Access", "Filtering Platform Connection")
    "5157" = @("Object Access", "Filtering Platform Connection")
    "5158" = @("Object Access", "Filtering Platform Connection")
    "5159" = @("Object Access", "Filtering Platform Connection")
    
    # Policy Change - Audit Policy Change
    "4715" = @("Policy Change", "Audit Policy Change")
    "4719" = @("Policy Change", "Audit Policy Change")
    "4817" = @("Policy Change", "Audit Policy Change")
    "4902" = @("Policy Change", "Audit Policy Change")
    "4904" = @("Policy Change", "Audit Policy Change")
    "4905" = @("Policy Change", "Audit Policy Change")
    "4906" = @("Policy Change", "Audit Policy Change")
    "4907" = @("Policy Change", "Audit Policy Change")
    "4908" = @("Policy Change", "Audit Policy Change")
    "4912" = @("Policy Change", "Audit Policy Change")
    
    # System - Security State Change
    "4608" = @("System", "Security State Change")
    "4609" = @("System", "Security State Change")
    "4616" = @("System", "Security State Change")
    "4621" = @("System", "Security State Change")
    
    # System - System Integrity
    "4612" = @("System", "System Integrity")
    "4615" = @("System", "System Integrity")
    "4618" = @("System", "System Integrity")
    "4816" = @("System", "System Integrity")
    "5038" = @("System", "System Integrity")
    "5056" = @("System", "System Integrity")
    "5057" = @("System", "System Integrity")
    "5060" = @("System", "System Integrity")
    "5061" = @("System", "System Integrity")
    "6281" = @("System", "System Integrity")
    "6410" = @("System", "System Integrity")
}

# Use Get-WinEvent -ListProvider directly but suppress errors
$providers = @()
try {
    $providers = Get-WinEvent -ListProvider * -ErrorAction SilentlyContinue -ErrorVariable providerErrors
} catch {
    # Just continue
}

$totalProviders = $providers.Count
Write-Host "Found $totalProviders providers to process"
Write-Host "Skipped $(($providerErrors | Measure-Object).Count) providers due to errors"

$eventCount = 0
$providerCount = 0

foreach ($provider in $providers) {
    $providerCount++
    $providerName = $provider.Name
    
    if ($providerCount % 10 -eq 0 -or $providerCount -eq 1) {
        $percentComplete = [math]::Round(($providerCount / $totalProviders) * 100, 1)
        Write-Host "Processing $providerCount of $totalProviders ($percentComplete%) - Currently: $providerName"
    }
    
    try {
        if ($provider.Events) {
            foreach ($event in $provider.Events) {
                $eventID = $event.Id
                
                # Get description if available
                $description = "No description available"
                if ($event.Description) {
                    # Clean up description
                    $description = $event.Description -replace '"', "'" -replace "`r`n", " " -replace "`n", " " -replace ',', ';'
                }
                
                # Try to get category and subcategory
                $category = "Uncategorized"
                $subcategory = "Uncategorized"
                
                if ($eventIDToCategory.ContainsKey($eventID.ToString())) {
                    $categoryInfo = $eventIDToCategory[$eventID.ToString()]
                    $category = $categoryInfo[0]
                    $subcategory = $categoryInfo[1]
                }
                
                # Write directly to file
                """$eventID"",""$providerName"",""$category"",""$subcategory"",""$description""" | Out-File -FilePath $outputFile -Encoding utf8 -Append
                $eventCount++
            }
        }
    }
    catch {
        # Just continue to the next provider
    }
}

Write-Host "Complete! Processed $providerCount providers and found $eventCount event IDs"
Write-Host "Results saved to $outputFile"

