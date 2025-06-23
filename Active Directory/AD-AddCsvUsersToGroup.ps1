<#
.SYNOPSIS
    Bulk add users to a AD security Group from a CSV file.
.DESCRIPTION
    This script allows you to bulk add users to an Active Directory security group using a CSV file.
    The CSV file should contain a column with the email addresses of the users you want to add.
    The script will extract the username from the email address and add it to the specified security group.
.NOTES
    Version: 1.0
    Updated: June 16, 2025
    Author: Josh Conway
    Previous: N/A
    Changelog:
        1.0 - Initial version
#>

# Import the Active Directory module if not already imported
Import-Module ActiveDirectory

# Define the name of the security group
$groupName = Read-Host -Prompt "Enter the name of the Security Group you wish to add the users to."

$CsvPath = Read-Host -Prompt "Enter the path to your csv file. (e.g., C:\Path\To\Your\Csv.csv)"

#Import CSV and adds each user to the specified group
Import-Csv -Path $CsvPath | ForEach-Object {
    $User = ($($_.mail) -replace "@.*", "$null")
    $UserSAM = (($User -replace '(?<=(.{20})).+'))

    # Iterate over each user in the CSV
    try {
        # Add the user to the group
        Add-ADGroupMember -Identity $groupName -Members $UserSAM
        Write-Host "Successfully added $User to $groupName"
    }
    catch {
        Write-Host "Failed to add $User to $groupName. Error: $($_.Exception.Message)"
    }
}