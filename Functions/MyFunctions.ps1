function Get-Choice {
    do {
        $choice = Read-Host "Do you want to run the script for (A)ll users, a (S)ingle user, or use a (C)SV of users? Enter A, S, or C"
        $choice = $choice.ToUpper()
        if ($choice -notin "A", "S", "C") {
            Write-Host "Invalid choice. Please enter A, S, or C."
        }
    } while ($choice -notin "A", "S", "C")
    return $choice
}

# Function to prompt for CSV input path
function Get-InputCsv {
    do {
        Write-Host "The CSV file must contain a single column named 'XXXX'. Press Enter to continue."
        [void][System.Console]::ReadLine()

        $inputCsv = Read-Host "Enter the full file path to the import CSV file"
        if (-not (Test-Path -Path $inputCsv -PathType Leaf)) {
            Write-Host "Invalid file path. Please enter a valid file path."
        }
    } while (-not (Test-Path -Path $inputCsv -PathType Leaf))
    return $inputCsv
}

# Function to prompt for CSV output path
function Get-OutputCsv {
    do {
        $outputCsv = Read-Host "Enter the full file path to export the results CSV file (Leave blank for default)"
        if ([string]::IsNullOrWhiteSpace($outputCsv)) {
            $outputCsv = "Results.csv"
        }
    
        $directory = [System.IO.Path]::GetDirectoryName($outputCsv)
        $filename = [System.IO.Path]::GetFileName($outputCsv)
        $extension = [System.IO.Path]::GetExtension($outputCsv)
        if (-not (Test-Path -Path $directory -PathType Container) -or [string]::IsNullOrWhiteSpace($filename) -or [string]::IsNullOrWhiteSpace($extension)) {
            Write-Host "Invalid file path. Please include a valid directory path and a filename with an extension."
        }
        elseif (Test-Path -Path $outputCsv) {
            $overwrite = Read-Host "File already exists. Do you want to overwrite it? (Y/N)"
            if ($overwrite -eq "N") {
                $outputCsv = $null
            }
        }
    } while (-not (Test-Path -Path $directory -PathType Container) -or [string]::IsNullOrWhiteSpace($filename) -or [string]::IsNullOrWhiteSpace($extension) -or ($null -eq $outputCsv))
    return $outputCsv
}

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
