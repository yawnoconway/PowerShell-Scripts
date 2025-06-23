<#
.SYNOPSIS
    Update the User Principal Name (UPN) for a specific user in Active Directory.
.DESCRIPTION
    This script updates the User Principal Name (UPN) for a specific user in Active Directory.
    It prompts for the SamAccountName of the user and constructs a new UPN based on the SamAccountName.
    The script then updates the user's UPN and displays the updated user information.
.NOTES
    Version: 1.0
    Updated: June 16, 2025
    Author: Josh Conway
    Previous: N/A
    Changelog:
        1.0 - Initial version
#>

Write-Host "This script will update UPN for a single, specific user.  This will usually be for a specific user that you have just created."  
Write-Host "  "
Write-Host "When prompted, simply provide the SamAccountName for the specific user." 

$sam = Read-Host "Enter SamAccountName for User: "

$User = Get-ADUser -Identity $sam

$newUPN = $user.SamAccountName+"@DOMAIN.com"

Set-ADUser -Identity $sam -UserPrincipalName $newUPN

Get-ADuser $sam