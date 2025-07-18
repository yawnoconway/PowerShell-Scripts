﻿<#
.SYNOPSIS
    Modify multiple Active Directory user attributes based on a CSV file.
.DESCRIPTION
    This script allows you to modify multiple attributes of Active Directory users based on data from a CSV file.
    The CSV file should contain columns for the user's email, manager, title, company, department, and other attributes.
    The script will check if the user exists in Active Directory and update their attributes accordingly.
    If a user does not exist, their email will be logged in a separate CSV file for review.
.NOTES
    Version: 1.0
    Updated: June 16, 2025
    Author: Josh Conway
    Previous: N/A
    Changelog:
        1.0 - Initial version
#>

#Imports ActiveDirectory Module
Import-Module ActiveDirectory

#Remove old "Non Existent Users" csv
Remove-Item -Path "C:\TEMP\non_existent_users.csv" -Force -ErrorAction SilentlyContinue

#Imports CSV and modifies the manager, title, company, and department attribute based on the samaccount name
Import-Csv -Path "PATH\TO\CSV.csv" | ForEach-Object {
    $EmpStatus  = $($_.EmpStatus)
    $User       = ($($_.mail) -replace "@.*", "$null")
    $Manager    = ($($_.manager) -replace "@.*", "$null")
    $UserSAM    = (($User -replace '(?<=(.{20})).+'))
    $ManagerSAM = (($Manager -replace '(?<=(.{20})).+'))

    # Check if the user exists in Active Directory
    $adUser = Get-ADUser -Filter "SamAccountName -eq '$UserSAM'" -ErrorAction SilentlyContinue
    if (!$adUser) {
        # User does not exist, export it to the CSV file
        [PSCustomObject]@{
            "Email in Workday" = $($_.mail)
        } | Export-Csv -Path "C:\TEMP\non_existent_users.csv" -Append -NoTypeInformation
    }
    else {
        if ($empstatus -eq "Inactive") {
            Set-ADUser -Identity $UserSAM -Replace @{empstatus = $($_.EmpStatus) }
            write-host "$($_.mail) 'User is Inactive'"
        }
        else {
            #Sets user account for modification, may or may not require '-Replace' depending on specific attribute
            Set-ADUser -Identity $UserSAM -Company $($_.LineOfBusiness)
            Set-ADUser -Identity $UserSAM -Department $($_.Department)
            Set-ADUser -Identity $UserSAM -Office $($_.PhysicalDeliveryOfficeName)
            Set-ADUser -Identity $UserSAM -employeeID $($_.EmployeeID)
            Set-ADUser -Identity $UserSAM -Title $($_.ExternalBusinessTitle)
            Set-ADUser -Identity $UserSAM -Replace @{universalID = $($_.UniversalID) }
            Set-ADUser -Identity $UserSAM -Replace @{employeeType = $($_.employeeType) }
            Set-ADUser -Identity $UserSAM -Replace @{empstatus = $($_.EmpStatus) }
            Set-ADUser -Identity $UserSAM -Replace @{jobclass = $($_.jobclass) }
            Set-ADUser -Identity $UserSAM -Replace @{extensionAttribute10 = $($_.UniversalID) }
            Set-ADUser -Identity $UserSAM -Replace @{extensionAttribute12 = $($_.employeeType) }
            Set-ADUser -Identity $UserSAM -Replace @{extensionAttribute13 = $($_.jobclass) }
            Set-ADUser -Identity $UserSAM -Replace @{extensionAttribute14 = $($_.EmpStatus) }
            Set-ADUser -Identity $UserSAM -Replace @{extensionAttribute15 = $($_.Country) }
   
            #The problematic ones below
            if ($($_.HireDate) -eq "$null") {
                set-ADuser -Identity $UserSAM -Replace @{extensionAttribute11 = "1/1/2020" }
            }
            else {
                set-ADuser -Identity $UserSAM -Replace @{extensionAttribute11 = $($_.HireDate) }
            }
            Set-ADUser -Identity $UserSAM -Manager $ManagerSAM
        }
    }
}