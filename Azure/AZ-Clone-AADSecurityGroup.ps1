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

# Replace these variables with your specific values
$oldGroupId = Read-Host -Prompt "Enter the Object ID that you wish to clone"
$newGroupName = Read-Host -Prompt "Enter the name for the new cloned group (e.g. Cloned-SecurityGroup)"
$newGroupDesc = Read-Host -Prompt "Enter a description for the new cloned group (e.g. This is a cloned security group)"
$newGroupMailNick = Read-Host -Prompt "Enter a mail nickname for the new cloned group (e.g. ClonedSecurityGroup)" # Must be unique in the tenant

# Ensure you have the necessary scopes to read/write groups and applications.
Connect-MgGraph -Scopes "Group.ReadWrite.All", "Directory.Read.All", "Application.ReadWrite.OwnedBy"

# Retrieve the source group
$oldGroup = Get-MgGroup -GroupId $oldGroupId
if (!$oldGroup) {
    Write-Host "Source group not found. Check the GroupId."
    return
}
Write-Host "Found source group:" $oldGroup.DisplayName

# Retrieve *all* members of the old group
$oldGroupMembers = Get-MgGroupMember -GroupId $oldGroupId -All
Write-Host "Old group membership count:" $oldGroupMembers.Count

# Create the new security group
$newGroup = New-MgGroup -SecurityEnabled $true `
    -DisplayName $newGroupName `
    -Description $newGroupDesc `
    -MailEnabled $false `
    -MailNickname $newGroupMailNick `
    -GroupTypes @() # For a simple security group, no M365 group types

Write-Host "Created new group:" $newGroup.DisplayName " (ObjectId: $($newGroup.Id))"

# Add the old group’s members to the new group
foreach ($member in $oldGroupMembers) {
    Add-MgGroupMember -GroupId $newGroup.Id -RefObjectId $member.Id
}
Write-Host "Copied over group membership to the new group."

# Copy the application role assignments from the old group to the new group
# Retrieve service principals that have app role assignments to old group
$appAssignments = Search-MgServicePrincipalAppRoleAssignedTo -Filter "principalId eq '$oldGroupId'" -All

Write-Host "Found $($appAssignments.Count) app role assignments for source group."

foreach ($assignment in $appAssignments) {
    New-MgServicePrincipalAppRoleAssignedTo `
        -ServicePrincipalId $assignment.ResourceId `
        -PrincipalId $newGroup.Id `
        -ResourceId $assignment.ResourceId `
        -AppRoleId $assignment.AppRoleId | Out-Null
}

Write-Host "Replicated application role assignments to new group."

Write-Host "`nCloning complete! New Group Object ID:" $newGroup.Id