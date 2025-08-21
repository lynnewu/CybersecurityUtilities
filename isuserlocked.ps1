param(
    [Parameter(Mandatory=$true)]
    [string]$Username
)

# Get the domain from environment variable, defaulting to current domain
$Domain = $env:USERDOMAIN

try {
    # Get AD user details
    $User = Get-ADUser -Identity $Username -Properties lastLogon, lastLogonTimestamp, lockedOut, badPwdCount, lastLogonDate, logonWorkstations -Server $Domain -ErrorAction Stop
    
    Write-Host "Account Details for $Username in domain $Domain" -ForegroundColor Green
    Write-Host "----------------------------------------" -ForegroundColor Green
    
    # Check if account is locked
    if ($User.LockedOut) {
        Write-Host "Account Status: LOCKED OUT" -ForegroundColor Red
    } else {
        Write-Host "Account Status: Not locked" -ForegroundColor Green
    }
    
    # Convert lastLogon timestamp and display
    if ($User.lastLogon -gt 0) {
        $LastLogon = [DateTime]::FromFileTime($User.lastLogon)
        Write-Host "Last Logon Time: $LastLogon" -ForegroundColor Yellow
    } else {
        Write-Host "Last Logon Time: Never logged in" -ForegroundColor Yellow
    }
    
    # Display workstations if available
    if ($User.logonWorkstations) {
        Write-Host "Allowed Workstations: $($User.logonWorkstations)" -ForegroundColor Yellow
    } else {
        Write-Host "Allowed Workstations: No restrictions" -ForegroundColor Yellow
    }
    
    # Display bad password count
    Write-Host "Bad Password Count: $($User.badPwdCount)" -ForegroundColor Yellow

} catch {
    Write-Host "Error: Unable to retrieve user information." -ForegroundColor Red
    Write-Host "Details: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}