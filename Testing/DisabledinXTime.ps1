#Connect-MgGraph -Scopes User.Read.All, AuditLog.Read.All, Directory.Read.All

# Get all users
#Get-MgUser -filter "accountEnabled eq false" -All | Select-Object Id, DisplayName, UserPrincipalName |
#Export-Csv -Path "PATH\TO\CSV\DisabledUsersLast6Months.csv" -NoTypeInformation





# Connect to Microsoft Graph
Connect-MgGraph -Scopes User.Read.All, AuditLog.Read.All, Directory.Read.All

# Calculate the date six months ago
$Time = (Get-Date).AddMonths(-6)

# Get all disabled users
$DisabledUsers = Get-MgUser -Filter "accountEnabled eq false" -All | Select-Object Id, DisplayName, UserPrincipalName

# Initialize an array to store the results
$DisabledUsersLast6Months = @()

# Iterate through each disabled user
foreach ($User in $DisabledUsers) {
    # Get audit logs for user account lifecycle changes
    $AuditLogs = Get-MgAuditLogDirectoryAudit -Filter "targetResources/any(t: t/id eq '$($User.Id)') and activityDisplayName eq 'Disable Account'" -All

    # Check if any disable event occurred in the last 6 months
    foreach ($Log in $AuditLogs) {
        if ($Log.ActivityDateTime -ge $Time) {
            $DisabledUsersLast6Months += $User
            break
        }
    }
}

# Export the filtered users to CSV
$DisabledUsersLast6Months | Export-Csv -Path "PATH\TO\CSV\DisabledUsersLast6Months.csv" -NoTypeInformation
