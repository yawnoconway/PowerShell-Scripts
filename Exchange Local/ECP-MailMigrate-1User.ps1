<#
.SYNOPSIS
    Mail-Enable a specific user in local Exchange.
.DESCRIPTION
    This script enables a single user for mail in an on-premises Exchange environment.
    It prompts for the username and constructs the UPN and Remote Routing Address based on the provided username.
    The script requires appropriate permissions to enable remote mailboxes in Exchange.
.NOTES
    Version: 1.0
    Updated: June 16, 2025
    Author: Josh Conway
    Previous: N/A
    Changelog:
        1.0 - Initial version
#>

Write-Host "This script will Mail-Enable a single, specific user.  This will usually be for a specific user that you have just created."  
Write-Host "  "
Write-Host "When prompted, simply provide the Username for the specific user. " 
Write-Host "  "

$user = Read-Host "Enter Username for User (e.g. first.last): "

$upn = $user + "@DOMAIN.com"
$RRA = $user + "@DOMAIN.mail.onmicrosoft.com"

Enable-RemoteMailbox $upn -RemoteRoutingAddress $RRA