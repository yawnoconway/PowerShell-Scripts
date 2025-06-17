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

Write-Host "This script will update UPN for a single, specific user.  This will usually be for a specific user that you have just created."  
Write-Host "  "
Write-Host "When prompted, simply provide the SamAccountName for the specific user." 

$sam = Read-Host "Enter SamAccountName for User: "

$User = Get-ADUser -Identity $sam

$newUPN = $user.SamAccountName+"@DOMAIN.com"

Set-ADUser -Identity $sam -UserPrincipalName $newUPN

Get-ADuser $sam