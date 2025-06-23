<#
.SYNOPSIS
    Hide users from the Global Address List (GAL) in Active Directory.
.DESCRIPTION
    This script modifies the msExchHideFromAddressLists attribute for all users in a specified Organizational Unit (OU) to hide them from the Global Address List (GAL).
    It also clears the ShowinAddressBook attribute for each user.
    The script prompts for the OU where the users are located.
.NOTES
    Version: 1.0
    Updated: June 16, 2025
    Author: Josh Conway
    Previous: N/A
    Changelog:
        1.0 - Initial version
#>

$BaseOU = Read-Host -Prompt "Enter the OU of users to modify. (e.g. 'OU=Current,OU=Users,OU=Business,DC=Example,DC=net')"

$users = get-adobject -filter {objectclass -eq "user"} -searchbase $BaseOU
foreach ($User in $users)
{
    Set-ADObject $user -replace @{msExchHideFromAddressLists=$true}
    Set-ADObject $user -clear ShowinAddressBook
}