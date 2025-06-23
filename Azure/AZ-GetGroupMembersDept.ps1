<#
.SYNOPSIS
    Export members of a specified Azure Active Directory Security Group to a CSV file, including user details like Display Name and Department.
.DESCRIPTION
    This script connects to Microsoft Graph, retrieves the members of a specified Azure AD Security Group,
    and exports their details (UserId, DisplayName, Department) to a CSV file.
    The script prompts for the group name and requires appropriate permissions to read group and user information.
.NOTES
    Version: 1.0
    Updated: June 16, 2025
    Author: Josh Conway
    Previous: N/A
    Changelog:
        1.0 - Initial version
#>

# Replace with the actual display name of the group
$groupName = Read-Host -Prompt "Enter the name of the Security Group you want the members of."

# Connect to Microsoft Graph
Connect-MgGraph -Scopes "Group.Read.All", "User.Read.All"

# Retrieve the group by display name
$group = Get-MgGroup -Filter "displayName eq '$groupName'"

# Check if the group was found
if ($group -and $group.Count -gt 0) {
    $groupId = $group.Id

    # Get the members of the group
    $groupMembers = Get-MgGroupMember -GroupId $groupId -All

    # Initialize an array to hold user details
    $userDetails = @()

    # Get user details for each member
    foreach ($member in $groupMembers) {
        if ($member['@odata.type'] -eq '#microsoft.graph.user') {
            $userId = $member.Id
            $user = Get-MgUser -UserId $userId -Property DisplayName,Department
            $userDetails += [PSCustomObject]@{
                UserId      = $userId
                DisplayName = $user.DisplayName
                Department  = $user.Department
            }
        }
    }

    # Define the path for the CSV file
    $csvPath = "$groupName.csv"

    # Export the user details to a CSV file
    $userDetails | Export-Csv -Path $csvPath -NoTypeInformation

    Write-Host "Exported group members to '$csvPath'"
} else {
    Write-Host "Group not found."
}