<#
.SYNOPSIS
    Modify an Active Directory attribute for users listed in a CSV file.
.DESCRIPTION
    This script allows you to modify a specific Active Directory attribute for users listed in a CSV file.
    The CSV file should contain columns for the user's email and the new value for the specified attribute.
    The script will read the data from the CSV file and update the specified attribute for each user.
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

$Attribute = Read-Host -Prompt "Enter the name of the AD Attribute you wish to modify."

$CsvPath = Read-Host -Prompt "Enter the path to your csv file. (e.g., C:\Path\To\Your\Csv.csv)"

#Import CSV and updates the specified attribute for each user
Import-Csv -Path $CsvPath | ForEach-Object {
    $NewAttribute = $($_.NewAttribute)
    $User = ($($_.mail) -replace "@.*", "$null")
    $UserSAM = (($User -replace '(?<=(.{20})).+'))

    # Iterate over each user in the CSV
    # Retrieve the user from Active Directory
    Get-ADUser -Filter "SamAccountName -eq '$UserSAM'" -ErrorAction SilentlyContinue

    # Update the user attributes
    Set-ADUser -Identity $UserSAM -Replace @{$Attribute = $($_.NewAttribute) }

    # Output the result for confirmation
    Write-Output "Updated user $User with ${Attribute}: $NewAttribute"
}