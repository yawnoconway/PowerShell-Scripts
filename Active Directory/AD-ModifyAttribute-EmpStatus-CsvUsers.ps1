# Import the Active Directory module if not already imported
Import-Module ActiveDirectory

$CsvPath = Read-Host -Prompt "Enter the path to your csv file. (e.g., C:\Path\To\Your\Csv.csv)"

#Imports CSV and modifies the manager, title, company, and department attribute based on the samaccount name
Import-Csv -Path $CsvPath | ForEach-Object {
    $EmpStatus = $($_.EmpStatus)
    $User = ($($_.mail) -replace "@.*", "$null")
    $UserSAM = (($User -replace '(?<=(.{20})).+'))

    # Iterate over each user in the CSV
    # Retrieve the user from Active Directory
    Get-ADUser -Filter "SamAccountName -eq '$UserSAM'" -ErrorAction SilentlyContinue

    # Update the user attributes
    Set-ADUser -Identity $UserSAM -Replace @{empstatus = $($_.EmpStatus) }
    Set-ADUser -Identity $UserSAM -Replace @{extensionAttribute14 = $($_.EmpStatus) }

    # Output the result for confirmation
    Write-Output "Updated user $User with EmpStatus: $EmpStatus"
}