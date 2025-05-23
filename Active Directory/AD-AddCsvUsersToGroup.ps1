# Import the Active Directory module if not already imported
Import-Module ActiveDirectory

# Define the name of the security group
$groupName = Read-Host -Prompt "Enter the name of the Security Group you wish to add the users to."

$CsvPath = Read-Host -Prompt "Enter the path to your csv file. (e.g., C:\Path\To\Your\Csv.csv)"

#Imports CSV and modifies the manager, title, company, and department attribute based on the samaccount name
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