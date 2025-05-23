# Import the Active Directory module if not already imported
Import-Module ActiveDirectory

$Attribute = Read-Host -Prompt "Enter the name of the AD Attribute you wish to modify."

$CsvPath = Read-Host -Prompt "Enter the path to your csv file. (e.g., C:\Path\To\Your\Csv.csv)"

#Imports CSV and modifies the manager, title, company, and department attribute based on the samaccount name
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
    Write-Output "Updated user $User with EmpStatus: $NewAttribute"
}