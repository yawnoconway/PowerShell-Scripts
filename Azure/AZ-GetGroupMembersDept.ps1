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