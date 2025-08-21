# Compare-ADUserGroups.ps1
# Purpose: Compares group memberships between two AD users and shows differences
# Usage: .\Compare-ADUserGroups.ps1 -User1 "username1" -User2 "username2"

param(
    [Parameter(Mandatory=$true)]
    [string]$User1,
    
    [Parameter(Mandatory=$true)]
    [string]$User2
)

# Check if Active Directory module is available
if (-not (Get-Module -ListAvailable -Name ActiveDirectory)) {
    Write-Error "Active Directory module not found. Please install RSAT tools or run this on a domain controller."
    exit 1
}

# Import the module if not already loaded
if (-not (Get-Module -Name ActiveDirectory)) {
    Import-Module ActiveDirectory
}

try {
    # Verify users exist
    try {
        $adUser1 = Get-ADUser -Identity $User1 -ErrorAction Stop
        $adUser2 = Get-ADUser -Identity $User2 -ErrorAction Stop
    }
    catch {
        Write-Error "One or both users not found. Please verify the usernames."
        exit 1
    }
    
    Write-Host "Comparing group memberships for users: '$User1' and '$User2'" -ForegroundColor Cyan
    
    # Get group memberships for both users
    $groups1 = Get-ADPrincipalGroupMembership -Identity $User1 | Select-Object -Property Name, DistinguishedName, SID | Sort-Object -Property Name
    $groups2 = Get-ADPrincipalGroupMembership -Identity $User2 | Select-Object -Property Name, DistinguishedName, SID | Sort-Object -Property Name
    
    # Count the groups
    $count1 = $groups1.Count
    $count2 = $groups2.Count
    
    Write-Host "`n$User1 belongs to $count1 groups" -ForegroundColor Green
    Write-Host "$User2 belongs to $count2 groups" -ForegroundColor Green
    
    # Find groups unique to each user
    $uniqueToUser1 = $groups1 | Where-Object { $groups2.SID -notcontains $_.SID }
    $uniqueToUser2 = $groups2 | Where-Object { $groups1.SID -notcontains $_.SID }
    
    # Find common groups
    $commonGroups = $groups1 | Where-Object { $groups2.SID -contains $_.SID }
    
    # Display results
    Write-Host "`nGroups unique to $User1 ($($uniqueToUser1.Count)):" -ForegroundColor Yellow
    if ($uniqueToUser1.Count -eq 0) {
        Write-Host "None" -ForegroundColor Gray
    } else {
        $uniqueToUser1 | Format-Table -Property Name, DistinguishedName -AutoSize
    }
    
    Write-Host "Groups unique to $User2 ($($uniqueToUser2.Count)):" -ForegroundColor Yellow
    if ($uniqueToUser2.Count -eq 0) {
        Write-Host "None" -ForegroundColor Gray
    } else {
        $uniqueToUser2 | Format-Table -Property Name, DistinguishedName -AutoSize
    }
    
    Write-Host "Groups common to both users ($($commonGroups.Count)):" -ForegroundColor Yellow
    if ($commonGroups.Count -eq 0) {
        Write-Host "None" -ForegroundColor Gray
    } else {
        $commonGroups | Format-Table -Property Name, DistinguishedName -AutoSize
    }
    
    # Summary - Fixed the colon issue by properly using string formatting
    Write-Host "`nSummary:" -ForegroundColor Cyan
    Write-Host "- Total groups for ${User1}: $count1" -ForegroundColor White
    Write-Host "- Total groups for ${User2}: $count2" -ForegroundColor White
    Write-Host "- Groups unique to ${User1}: $($uniqueToUser1.Count)" -ForegroundColor White
    Write-Host "- Groups unique to ${User2}: $($uniqueToUser2.Count)" -ForegroundColor White
    Write-Host "- Groups in common: $($commonGroups.Count)" -ForegroundColor White
}
catch {
    Write-Error "Error comparing user groups: $_"
    exit 1
}
