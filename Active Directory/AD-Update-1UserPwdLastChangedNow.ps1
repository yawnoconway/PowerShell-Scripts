<#
.SYNOPSIS
    Update the PwdLastSet attribute for a specific user in Active Directory.
.DESCRIPTION
    This script updates the PwdLastSet attribute for a specific user in Active Directory.
    It sets the password to expired, allows the password to be changed, and resets the last password change date to today.
    The script prompts for the username of the user whose password needs to be updated.
.NOTES
    Version: 1.0
    Updated: June 16, 2025
    Author: Josh Conway
    Previous: N/A
    Changelog:
        1.0 - Initial version
#>

Write-Host "This script will update Pwd Last set for a single, specific user."  
Write-Host "  "
Write-Host "When prompted, simply provide the Username for the specific user." 

$userName = Read-Host "Enter Username for User (e.g. first.last): "
$userSAM = (($userName -replace '(?<=(.{20})).+'))

$ADUser = Get-ADUser $userSAM

# Set the password to expired, must be done first.
$ADUser.pwdLastSet = 0
# Set the account so that the password expires.
$ADUser.PasswordNeverExpires = $False
# Save the changes
Set-ADUser -Instance $ADUser
 
# Reset the date of the last password change to today.
$ADUser.pwdLastSet = -1
# Save the changes
Set-ADUser -Instance $ADUser
 
# Inform the user of the script that the account was changed.
Write-Host    $ADUser.Name+"  Account Changed."