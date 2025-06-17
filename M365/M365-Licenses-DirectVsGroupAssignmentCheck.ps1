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

# Connect to Graph
Connect-MgGraph -Scopes "User.Read.All", "Directory.ReadWrite.All"

# Prompt for the SkuPartNumber
$skuPartNumber = Read-Host -Prompt "Enter the SKU Part Number (e.g. 'MICROSOFT_365_COPILOT')"

# Define function
function Get-LicenseAssignments {
    param(
        [string]$SkuPartNumber
    )

    # Validate an actual value was entered
    if (-not $SkuPartNumber) {
        Write-Host "You did not provide a SKU Part Number. Exiting..." -ForegroundColor Red
        return @()
    }

    # A small cache to avoid repeated lookups of the same group.
    $groupCache = [System.Collections.Generic.Dictionary[string, string]]::new()

    # Identify the Copilot SKU object (which will have SkuId & SkuPartNumber)
    $SkuObject = Get-MgSubscribedSku | Where-Object { $_.SkuPartNumber -eq $SkuPartNumber }
    if (-not $SkuObject) {
        Write-Host "ERROR: Could not find the '$SkuPartNumber' SKU in the tenant." -ForegroundColor Red
        return @() # Return an empty array on error
    }

    $SkuId = $SkuObject.SkuId
    Write-Host "Retrieving user data..."

    # Retrieve all users
    $allUsers = Get-MgUser -All -Property "displayName,userPrincipalName,licenseAssignmentStates"

    # Go through each user and figure out if/where they got the license
    $resultList = @()
    foreach ($user in $allUsers) {
        # Filter the states for just the SkuId
        $Assignments = $user.LicenseAssignmentStates | Where-Object { $_.SkuId -eq $SkuId }
        if ($Assignments) {
            # Build string that notes how the user got the license
            $methods = foreach ($assignment in $Assignments) {
                if ($assignment.AssignedByGroup) {
                    # Check cache
                    if (-not $groupCache.ContainsKey($assignment.AssignedByGroup)) {
                        try {
                            $grp = Get-MgGroup -GroupId $assignment.AssignedByGroup
                            $groupCache[$assignment.AssignedByGroup] = $grp.DisplayName
                        }
                        catch {
                            $groupCache[$assignment.AssignedByGroup] = "Unknown Group"
                        }
                    }
                    $groupDisplayName = $groupCache[$assignment.AssignedByGroup]
                    "Group: $groupDisplayName ($($assignment.AssignedByGroup))"
                }
                else {
                    "Direct"
                }
            }

            # Remove duplicates if the user appears multiple times
            $methods = $methods | Sort-Object -Unique
            $assignmentType = $methods -join "; "

            # Add final record
            $resultList += [pscustomobject]@{
                DisplayName          = $user.DisplayName
                UserPrincipalName    = $user.UserPrincipalName
                LicenseSkuPartNumber = $SkuPartNumber
                LicenseSkuId         = $SkuId
                AssignmentType       = $assignmentType
            }
        }
    }

    return $resultList
}

Write-Host "`nGathering License Assignments for $($skuPartNumber)..."
$allResults = Get-LicenseAssignments -SkuPartNumber $skuPartNumber

if (-not $allResults) {
    Write-Host "No results returned. Exiting."
    return
}

# Identify which users have both Direct and Group-based assignments
$usersWithBoth = $allResults | Where-Object {
    $_.AssignmentType -match 'Direct' -and $_.AssignmentType -match 'Group:'
}

if ($usersWithBoth.Count -gt 0) {
    Write-Host "`nFound $($usersWithBoth.Count) user(s) who have both Direct and Group-based licenses."
    $resp = Read-Host -Prompt "Do you want to remove the direct license from these users? (Y/N)"

    if ($resp.ToUpper() -eq "Y") {
        foreach ($userRecord in $usersWithBoth) {
            Write-Host "Removing direct license for $($userRecord.UserPrincipalName)..."
            Set-MgUserLicense -UserId $userRecord.UserPrincipalName -AddLicenses @() -RemoveLicenses @($userRecord.LicenseSkuId)
        }
        Write-Host "Direct licenses removed."
    }
    else {
        Write-Host "No direct license removals performed."
    }
}
else {
    Write-Host "`nNo users found with both Direct and Group-based assignments."
}

# Refresh results one more time to see final state
Write-Host "`nGathering final License Assignments..."
$finalResults = Get-LicenseAssignments -SkuPartNumber $skuPartNumber

# Export final results to CSV
$csvPath = "C:\Temp\LicenseAssignments.csv"
Write-Host "`nExporting final results to $csvPath..."
$finalResults | Export-Csv -Path $csvPath -NoTypeInformation

Write-Host "Done!"