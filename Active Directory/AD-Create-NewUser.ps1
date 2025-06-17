<#
.SYNOPSIS
    Add Synopsis Here
.DESCRIPTION
    Add Description Here
.NOTES
    Version: 1.0
    Updated: June 16, 2025
    Author: Josh Conway
    Previous: N/A
    Changelog:
        1.0 - Initial version
#>

#  Set AD Path to OU for new users
$path = "DISTINGUISHED OU"

$userGivenName = Read-Host "New User Given Name? "
$userSurname = Read-Host "New User Surname? "
$userName = Read-Host "New User Username (e.g. first.last)? "
$UserSAM = (($userName -replace '(?<=(.{20})).+'))
$userPassword = Read-Host "New User Password (min 14 characters)?"
$userDescription = Read-Host "New User Description? "
$name = $userGivenName + " " + $userSurname
$displayName = $userGivenName + " " + $userSurname 
$securePwd = ConvertTo-SecureString $userPassword -AsPlainText -Force
$UPN = $userName + "@DOMAIN.com"

$parms = @{
    'Name'              = $name;
    'AccountPassword'   = $securePwd;
    'DisplayName'       = $displayName; 
    'GivenName'         = $userGivenName; 
    'Description'       = $userDescription; 
    'Path'              = $path; 
    'SamAccountName'    = $userSAM; 
    'Surname'           = $userSurname; 
    'UserPrincipalName' = $UPN; 
    'Enabled'           = $true;
}

New-ADUser @parms
