param(
    [Parameter(Mandatory=$false)]
    [switch]$OutputToFile
)

# Import the Active Directory module (if not already loaded)
Import-Module ActiveDirectory

# Create timestamp for filenames
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"

# Helper function to handle multi-valued attributes
function Format-ADValue {
    param($Value)
    if ($Value -is [Microsoft.ActiveDirectory.Management.ADPropertyValueCollection]) {
        return ($Value -join ';')
    }
    return $Value
}

# Get computers with Unconstrained Delegation
$computers = Get-ADComputer -Filter {TrustedForDelegation -eq $true} -Properties Name, TrustedForDelegation, UserAccountControl, DistinguishedName |
             Select-Object @{
                 Name = 'Name'
                 Expression = { $_.Name }
             },
             @{
                 Name = 'UserAccountControl'
                 Expression = { $_.UserAccountControl }
             },
             @{
                 Name = 'DistinguishedName'
                 Expression = { $_.DistinguishedName }
             }

# Output computer results
Write-Output "`nComputers with Unconstrained Delegation:"
if ($computers) {
    $computers | ConvertTo-Csv -NoTypeInformation | ForEach-Object { Write-Output $_ }
    
    if ($OutputToFile) {
        $computerFile = "UnconstrainedDelegation_Computers_$timestamp.csv"
        $computers | Export-Csv -Path $computerFile -NoTypeInformation
        Write-Output "`nComputer results also saved to: $computerFile"
    }
} else {
    Write-Output "No computers found with Unconstrained Delegation enabled."
}

# Get accounts with Unconstrained Delegation
$accounts = Get-ADUser -Filter {TrustedForDelegation -eq $True} -Properties TrustedForDelegation,ServicePrincipalName,Description,DistinguishedName |
            Select-Object @{
                Name = 'Name'
                Expression = { $_.Name }
            },
            @{
                Name = 'SamAccountName'
                Expression = { $_.SamAccountName }
            },
            @{
                Name = 'ServicePrincipalName'
                Expression = { Format-ADValue $_.ServicePrincipalName }
            },
            @{
                Name = 'Description'
                Expression = { $_.Description }
            },
            @{
                Name = 'DistinguishedName'
                Expression = { $_.DistinguishedName }
            }

# Output account results
Write-Output "`nAccounts with Unconstrained Delegation:"
if ($accounts) {
    $accounts | ConvertTo-Csv -NoTypeInformation | ForEach-Object { Write-Output $_ }
    
    if ($OutputToFile) {
        $accountFile = "UnconstrainedDelegation_Accounts_$timestamp.csv"
        $accounts | Export-Csv -Path $accountFile -NoTypeInformation
        Write-Output "`nAccount results also saved to: $accountFile"
    }
} else {
    Write-Output "No accounts found with Unconstrained Delegation enabled."
}