<#
.SYNOPSIS
    Move users to a new Organizational Unit (OU) based on a specific attribute.
.DESCRIPTION
    This script moves users from a specified source OU to a target OU if a specific attribute (e.g., extensionAttribute10) is not blank.
    The script prompts for the source and target OUs and checks each user in the source OU for the specified attribute.
    If the attribute is not blank, the user is moved to the target OU.
.NOTES
    Version: 1.0
    Updated: June 16, 2025
    Author: Josh Conway
    Previous: N/A
    Changelog:
        1.0 - Initial version
#>

# Define the distinguished name (DN) of the source OU and the target OU
$sourceOU = Read-Host -Prompt "Enter the Source OU of users to move. (e.g. 'OU=Current,OU=Users,OU=Business,DC=Example,DC=net')"
$targetOU = Read-Host -Prompt "Enter the Target OU to move the users to. (e.g. 'OU=Current,OU=Users,OU=Business,DC=Example,DC=net')"
$attributeToCheck = "extensionAttribute10"

# Get all user objects in the source OU
$users = Get-ADUser -Filter * -SearchBase $sourceOU -Properties $attributeToCheck

# Iterate over each user to check if the attribute is not blank
foreach ($user in $users) {
    # Check if the attribute is not blank
    if (![string]::IsNullOrWhiteSpace($user.$attributeToCheck)) {
        # Move the user to the target OU
        try {
            Move-ADObject -Identity $user -TargetPath $targetOU
            Write-Host "Moved user $($user.SamAccountName) to $targetOU"
        } catch {
            Write-Host "Failed to move user $($user.SamAccountName): $_"
        }
    }
}