#
#  lu.ps1 - Look up User(s) in ActiveDirectory using complete or partial usernames.  Multiple usernames must be in the form of "a,b,c" (including the double quotes)
#
#  Usage: lu [<username> -or- "<username>,..."] [-csv]
#    If no arguments are specified, all users are retrieved and output is written to console.
#    CSV output filename is generated automatically
#
#  History:
#    2024-10-03-1411 - lwhitehorn@silverstarbrands.com - initial creation
#
param (
    [string]$UserNames,
    [switch]$csv
)

# Get the script name
$scriptName = $MyInvocation.MyCommand.Name

#  see end of file for a list of all AD User properties
#$props = @('sAMAccountName', 'Created', 'LastLogonDate', 'LastBadPasswordAttempt', 'Modified', 'PasswordExpired', 'PasswordLastSet', 'PasswordNotRequired', 'Department', 'Manager', 'Title', 'sAMAccountType')
$props = @('sAMAccountName', 'GivenName', 'Surname', 'EmailAddress', 'Enabled','LockedOut', 'WhenChanged', 'Created', 'LastLogonDate', 'PasswordExpired', 'PasswordLastSet', 'PasswordNotRequired', 'Department', 'Manager', 'Title', 'sAMAccountType')


# Validate input
if (-not $UserNames) {
    Write-Host "We would also have accepted: .\$scriptName <username pattern> or `"<username pattern>,...`" "
}

# Split the input string into an array using a comma as the delimiter
$userArray = $Usernames -split ','

# Prepare a collection for the users
$users = @()

# Get users based on the provided argument or all users if no argument is given
if ([string]::IsNullOrEmpty($Usernames)) {
   write-host "Getting all users"
   $users = Get-ADUser -Filter * -Properties *

} else {
  # Loop through each username and retrieve the corresponding AD users
  foreach ($username in $userArray) {
    Write-Host "Processing: $username"
    if ([string]::IsNullOrEmpty($username)) {
        continue  # Skip empty entries
    }
    $users += Get-ADUser -Filter "UserPrincipalName -like '*$username*'" -Properties *
  }
}


# Check if any users were found
if ($users) {

    # Create a list to hold the output objects
    $output = @()  # Initialize an empty array

    # Process each user
    foreach ($user in $users) {
        # Create a custom PSObject for each user
        $userObject = [PSCustomObject]@{}

        # Add properties from the props list
        foreach ($property in $props) {
            $userObject | Add-Member -MemberType NoteProperty -Name $property -Value $user.$property
        }

	# Determine the human-readable AccountType based on sAMAccountType
	$accountType = switch ($user.sAMAccountType) {
	    0 { "Undefined" }
	    512 { "User Account" }
    	    513 { "Group Account" }
    	    514 { "Domain Group Account" }
    	    544 { "Domain Local Group Account" }
    	    545 { "Global Group Account" }
    	    546 { "Universal Group Account" }
    	    268435456 { "Computer Account" }
    	    268435457 { "Service Account" }
    	    268435458 { "Interdomain Trust Account" }
    	    268435459 { "Workstation Trust Account" }
    	    268435460 { "Internet Domain Account" }
    	    268435461 { "Self-Managed Account" }
    	    268435462 { "Contact Account" }
    	    268435463 { "Application Account" }
    	    805306368 { "User Object (SAM_USER_OBJECT)" }  # Updated for clarity
    	    805306369 { "Domain Computer Account" }
    	    805306370 { "Managed Service Account" }
    	    805306371 { "Group Managed Service Account" }
    	    805306372 { "Domain Managed Service Account" }
    	    default { "Unknown Account Type: $($user.sAMAccountType)" }
	}


        # Debugging line to show the computed AccountType
#        Write-Host "Computed AccountType for $($user.sAMAccountName): $accountType"

        # Add the AccountType property
        $userObject | Add-Member -MemberType NoteProperty -Name "AccountType" -Value $accountType

	#Write-Host "userObject:" $userObject

        # Add the userObject to the output array
        $output += $userObject

    }


    #write-host "output: " $output



    # Output the custom objects as a table
#    $output | Format-Table -Property ($props + 'AccountType') -AutoSize -Wrap
#    $output | Format-Table -Property ($props + 'AccountType') -AutoSize 



     # Determine the output file name if -csv is specified
     if ($csv) {
         $date = (Get-Date).ToString("yyyy-MM-ddTHH-mm-ss")  # ISO 8601 format
	 $outputFile = "ad-users-$date.csv"
	 $outputPath = "$outputFile"
	 # Export the users to a CSV file with headers
	 $output | Export-Csv -Path $outputPath -NoTypeInformation -Force
	 Write-Host "output written to " $outputPath

	 } else {
	   # If -csv is not specified, output to the console
	   $output | Format-Table -Property ($props + 'AccountType') -AutoSize -wrap
#	   $output | Format-Table -AutoSize -wrap
	 }

} else {
    Write-Host "No users found with UserPrincipalName containing '$UserName'."
}


#  exit the script and not the CLI
return



<#

The output of:
    PS> Get-ADUser -Properties * -Filter * | Select-Object -First 1 | Get-Member -MemberType Properties


TypeName: Microsoft.ActiveDirectory.Management.ADUser

Name                                 MemberType Definition                                                                                                                         
----                                 ---------- ----------                                                                                                                         
AccountExpirationDate                Property   System.DateTime AccountExpirationDate {get;set;}                                                                                   
accountExpires                       Property   System.Int accountExpires {get;set;}                                                                                             
AccountLockoutTime                   Property   System.DateTime AccountLockoutTime {get;set;}                                                                                      
AccountNotDelegated                  Property   System.Boolean AccountNotDelegated {get;set;}                                                                                      
adminCount                           Property   System.Int32 adminCount {get;set;}                                                                                                 
AllowReversiblePasswordEncryption    Property   System.Boolean AllowReversiblePasswordEncryption {get;set;}                                                                        
AuthenticationPolicy                 Property   Microsoft.ActiveDirectory.Management.ADPropertyValueCollection AuthenticationPolicy {get;set;}                                     
AuthenticationPolicySilo             Property   Microsoft.ActiveDirectory.Management.ADPropertyValueCollection AuthenticationPolicySilo {get;set;}                                 
BadLogonCount                        Property   System.Int32 BadLogonCount {get;}                                                                                                  
badPasswordTime                      Property   System.Int64 badPasswordTime {get;set;}                                                                                            
badPwdCount                          Property   System.Int32 badPwdCount {get;set;}                                                                                                
CannotChangePassword                 Property   System.Boolean CannotChangePassword {get;set;}                                                                                     
CanonicalName                        Property   System.String CanonicalName {get;}                                                                                                 
Certificates                         Property   Microsoft.ActiveDirectory.Management.ADPropertyValueCollection Certificates {get;set;}                                             
City                                 Property   System.String City {get;set;}                                                                                                      
CN                                   Property   System.String CN {get;}                                                                                                            
co                                   Property   System.String co {get;set;}                                                                                                        
codePage                             Property   System.Int32 codePage {get;set;}                                                                                                   
Company                              Property   System.String Company {get;set;}                                                                                                   
CompoundIdentitySupported            Property   Microsoft.ActiveDirectory.Management.ADPropertyValueCollection CompoundIdentitySupported {get;set;}                                
Country                              Property   System.String Country {get;set;}                                                                                                   
countryCode                          Property   System.Int32 countryCode {get;set;}                                                                                                
Created                              Property   System.DateTime Created {get;}                                                                                                     
createTimeStamp                      Property   System.DateTime createTimeStamp {get;}                                                                                             
Deleted                              Property   System.Boolean Deleted {get;}                                                                                                      
Department                           Property   System.String Department {get;set;}                                                                                                
Description                          Property   System.String Description {get;set;}                                                                                               
DisplayName                          Property   System.String DisplayName {get;set;}                                                                                               
DistinguishedName                    Property   System.String DistinguishedName {get;set;}                                                                                         
Division                             Property   System.String Division {get;set;}                                                                                                  
DoesNotRequirePreAuth                Property   System.Boolean DoesNotRequirePreAuth {get;set;}                                                                                    
dSCorePropagationData                Property   Microsoft.ActiveDirectory.Management.ADPropertyValueCollection dSCorePropagationData {get;}                                        
EmailAddress                         Property   System.String EmailAddress {get;set;}                                                                                              
EmployeeID                           Property   System.String EmployeeID {get;set;}                                                                                                
EmployeeNumber                       Property   System.String EmployeeNumber {get;set;}                                                                                            
Enabled                              Property   System.Boolean Enabled {get;set;}                                                                                                  
facsimileTelephoneNumber             Property   System.String facsimileTelephoneNumber {get;set;}                                                                                  
Fax                                  Property   System.String Fax {get;set;}                                                                                                       
GivenName                            Property   System.String GivenName {get;set;}                                                                                                 
HomeDirectory                        Property   System.String HomeDirectory {get;set;}                                                                                             
HomedirRequired                      Property   System.Boolean HomedirRequired {get;set;}                                                                                          
HomeDrive                            Property   System.String HomeDrive {get;set;}                                                                                                 
HomePage                             Property   System.String HomePage {get;set;}                                                                                                  
HomePhone                            Property   System.String HomePhone {get;set;}                                                                                                 
info                                 Property   System.String info {get;set;}                                                                                                      
Initials                             Property   System.String Initials {get;set;}                                                                                                  
instanceType                         Property   System.Int32 instanceType {get;}                                                                                                   
isCriticalSystemObject               Property   System.Boolean isCriticalSystemObject {get;set;}                                                                                   
isDeleted                            Property   System.Boolean isDeleted {get;}                                                                                                    
KerberosEncryptionType               Property   Microsoft.ActiveDirectory.Management.ADPropertyValueCollection KerberosEncryptionType {get;set;}                                   
l                                    Property   System.String l {get;set;}                                                                                                         
LastBadPasswordAttempt               Property   System.DateTime LastBadPasswordAttempt {get;}                                                                                      
LastKnownParent                      Property   System.String LastKnownParent {get;}                                                                                               
LastLogonDate                        Property   System.DateTime LastLogonDate {get;}                                                                                               
lastLogonTimestamp                   Property   System.Int64 lastLogonTimestamp {get;set;}                                                                                         
LockedOut                            Property   System.Boolean LockedOut {get;set;}                                                                                                
lockoutTime                          Property   System.Int64 lockoutTime {get;set;}                                                                                                
LogonWorkstations                    Property   System.String LogonWorkstations {get;set;}                                                                                         
managedObjects                       Property   Microsoft.ActiveDirectory.Management.ADPropertyValueCollection managedObjects {get;}                                               
Manager                              Property   System.String Manager {get;set;}                                                                                                   
MemberOf                             Property   Microsoft.ActiveDirectory.Management.ADPropertyValueCollection MemberOf {get;}                                                     
MNSLogonAccount                      Property   System.Boolean MNSLogonAccount {get;set;}                                                                                          
mobile                               Property   System.String mobile {get;set;}                                                                                                    
MobilePhone                          Property   System.String MobilePhone {get;set;}                                                                                               
Modified                             Property   System.DateTime Modified {get;}                                                                                                    
modifyTimeStamp                      Property   System.DateTime modifyTimeStamp {get;}                                                                                             
msDS-SupportedEncryptionTypes        Property   System.Int32 msDS-SupportedEncryptionTypes {get;set;}                                                                              
msDS-User-Account-Control-Computed   Property   System.Int32 msDS-User-Account-Control-Computed {get;}                                                                             
msExchALObjectVersion                Property   System.Int32 msExchALObjectVersion {get;set;}                                                                                      
msExchAssistantName                  Property   System.String msExchAssistantName {get;set;}                                                                                       
msExchOmaAdminWirelessEnable         Property   System.Int32 msExchOmaAdminWirelessEnable {get;set;}                                                                               
msExchUMDtmfMap                      Property   Microsoft.ActiveDirectory.Management.ADPropertyValueCollection msExchUMDtmfMap {get;set;}                                          
msExchWhenMailboxCreated             Property   System.DateTime msExchWhenMailboxCreated {get;set;}                                                                                
mSMQDigests                          Property   Microsoft.ActiveDirectory.Management.ADPropertyValueCollection mSMQDigests {get;set;}                                              
mSMQSignCertificates                 Property   System.Byte[] mSMQSignCertificates {get;set;}                                                                                      
Name                                 Property   System.String Name {get;}                                                                                                          
nTSecurityDescriptor                 Property   System.DirectoryServices.ActiveDirectorySecurity nTSecurityDescriptor {get;set;}                                                   
ObjectCategory                       Property   System.String ObjectCategory {get;}                                                                                                
ObjectClass                          Property   System.String ObjectClass {get;set;}                                                                                               
ObjectGUID                           Property   System.Nullable`1[[System.Guid, mscorlib, Version=4.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089]] ObjectGUID {get;set;}
objectSid                            Property   System.Security.Principal.SecurityIdentifier objectSid {get;}                                                                      
Office                               Property   System.String Office {get;set;}                                                                                                    
OfficePhone                          Property   System.String OfficePhone {get;set;}                                                                                               
Organization                         Property   System.String Organization {get;set;}                                                                                              
otherHomePhone                       Property   Microsoft.ActiveDirectory.Management.ADPropertyValueCollection otherHomePhone {get;set;}                                           
OtherName                            Property   System.String OtherName {get;set;}                                                                                                 
otherTelephone                       Property   Microsoft.ActiveDirectory.Management.ADPropertyValueCollection otherTelephone {get;set;}                                           
pager                                Property   System.String pager {get;set;}                                                                                                     
PasswordExpired                      Property   System.Boolean PasswordExpired {get;set;}                                                                                          
PasswordLastSet                      Property   System.DateTime PasswordLastSet {get;set;}                                                                                         
PasswordNeverExpires                 Property   System.Boolean PasswordNeverExpires {get;set;}                                                                                     
PasswordNotRequired                  Property   System.Boolean PasswordNotRequired {get;set;}                                                                                      
physicalDeliveryOfficeName           Property   System.String physicalDeliveryOfficeName {get;set;}                                                                                
POBox                                Property   System.String POBox {get;set;}                                                                                                     
PostalCode                           Property   System.String PostalCode {get;set;}                                                                                                
PrimaryGroup                         Property   System.String PrimaryGroup {get;}                                                                                                  
primaryGroupID                       Property   System.Int32 primaryGroupID {get;set;}                                                                                             
PrincipalsAllowedToDelegateToAccount Property   Microsoft.ActiveDirectory.Management.ADPropertyValueCollection PrincipalsAllowedToDelegateToAccount {get;set;}                     
ProfilePath                          Property   System.String ProfilePath {get;set;}                                                                                               
ProtectedFromAccidentalDeletion      Property   System.Boolean ProtectedFromAccidentalDeletion {get;set;}                                                                          
protocolSettings                     Property   Microsoft.ActiveDirectory.Management.ADPropertyValueCollection protocolSettings {get;set;}                                         
pwdLastSet                           Property   System.Int64 pwdLastSet {get;set;}                                                                                                 
SamAccountName                       Property   System.String SamAccountName {get;set;}                                                                                            
sAMAccountType                       Property   System.Int32 sAMAccountType {get;set;}                                                                                             
ScriptPath                           Property   System.String ScriptPath {get;set;}                                                                                                
sDRightsEffective                    Property   System.Int32 sDRightsEffective {get;}                                                                                              
ServicePrincipalNames                Property   Microsoft.ActiveDirectory.Management.ADPropertyValueCollection ServicePrincipalNames {get;set;}                                    
SID                                  Property   System.Security.Principal.SecurityIdentifier SID {get;set;}                                                                        
SIDHistory                           Property   Microsoft.ActiveDirectory.Management.ADPropertyValueCollection SIDHistory {get;}                                                   
SmartcardLogonRequired               Property   System.Boolean SmartcardLogonRequired {get;set;}                                                                                   
st                                   Property   System.String st {get;set;}                                                                                                        
State                                Property   System.String State {get;set;}                                                                                                     
StreetAddress                        Property   System.String StreetAddress {get;set;}                                                                                             
Surname                              Property   System.String Surname {get;set;}                                                                                                   
telephoneAssistant                   Property   System.String telephoneAssistant {get;set;}                                                                                        
telephoneNumber                      Property   System.String telephoneNumber {get;set;}                                                                                           
Title                                Property   System.String Title {get;set;}                                                                                                     
TrustedForDelegation                 Property   System.Boolean TrustedForDelegation {get;set;}                                                                                     
TrustedToAuthForDelegation           Property   System.Boolean TrustedToAuthForDelegation {get;set;}                                                                               
UseDESKeyOnly                        Property   System.Boolean UseDESKeyOnly {get;set;}                                                                                            
userAccountControl                   Property   System.Int32 userAccountControl {get;set;}                                                                                         
userCertificate                      Property   Microsoft.ActiveDirectory.Management.ADPropertyValueCollection userCertificate {get;set;}                                          
UserPrincipalName                    Property   System.String UserPrincipalName {get;set;}                                                                                         
uSNChanged                           Property   System.Int64 uSNChanged {get;}                                                                                                     
uSNCreated                           Property   System.Int64 uSNCreated {get;}                                                                                                     
whenChanged                          Property   System.DateTime whenChanged {get;}                                                                                                 
whenCreated                          Property   System.DateTime whenCreated {get;}                                                                                                 


#>