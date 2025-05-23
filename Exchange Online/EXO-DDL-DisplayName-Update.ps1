# Check if the user is connected to Exchange Online
$getSessions = Get-ConnectionInformation | Select-Object Name
$isConnected = (@($getSessions.Name) -like 'ExchangeOnline*').Count -gt 0
If ($isConnected -ne 'True') {
    Connect-ExchangeOnline -ShowBanner:$false
}

# Function to prompt for a valid choice
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
        Write-Host "The CSV file must contain a single column named 'Email'. Press Enter to continue."
        [void][System.Console]::ReadLine()

        $inputCsv = Read-Host "Enter the full file path to the import CSV file"
        if (-not (Test-Path -Path $inputCsv -PathType Leaf)) {
            Write-Host "Invalid file path. Please enter a valid file path."
        }
    } while (-not (Test-Path -Path $inputCsv -PathType Leaf))
    return $inputCsv
}

function Get-OutputCsv {
    do {
        $outputCsv = Read-Host "Enter the full file path to export the results CSV file (Leave blank for default)"
        if ([string]::IsNullOrWhiteSpace($outputCsv)) {
            $outputCsv = "Results.csv"
        }
    
        $directory = [System.IO.Path]::GetDirectoryName($outputCsv)
        $filename = [System.IO.Path]::GetFileName($outputCsv)
        $extension = [System.IO.Path]::GetExtension($outputCsv)
        
        # Handle relative paths (including default "Results.csv")
        if ([string]::IsNullOrWhiteSpace($directory)) {
            $directory = (Get-Location).Path
            $fullPath = Join-Path -Path $directory -ChildPath $outputCsv
        }
        else {
            $fullPath = $outputCsv
        }
        
        # Validate filename and extension
        if ([string]::IsNullOrWhiteSpace($filename) -or [string]::IsNullOrWhiteSpace($extension)) {
            Write-Host "Invalid file path. Please include a filename with an extension."
            $isValid = $false
        }
        # Validate directory exists
        elseif (-not (Test-Path -Path $directory -PathType Container)) {
            Write-Host "Invalid directory path. Please include a valid directory path."
            $isValid = $false
        }
        else {
            $isValid = $true
            # Check if file exists for overwrite prompt
            if (Test-Path -Path $fullPath) {
                $overwrite = Read-Host "File already exists. Do you want to overwrite it? (Y/N)"
                if ($overwrite -ne "Y") {
                    $outputCsv = $null
                    $isValid = $false
                }
            }
        }
    } while (-not $isValid)
    
    # Return the full path with directory if it was a relative path
    if ([System.IO.Path]::IsPathRooted($outputCsv)) {
        return $outputCsv
    }
    else {
        return (Join-Path -Path (Get-Location).Path -ChildPath $outputCsv)
    }
}

# Prompt user for input
$choice = Get-Choice

# Execute based on user choice
switch ($choice) {
    "A" {
        # Define the path to the output CSV file where results will be saved
        $outputCsv = Get-OutputCsv
        
        # Create an array to store the changes
        $results = @()

        # Get all dynamic distribution lists
        try {
            $dynamicDLs = Get-DynamicDistributionGroup
        }
        catch {
            Write-Host "Failed to retrieve dynamic distribution groups: $_"
        }

        # Loop through each dynamic distribution list and update the DisplayName
        foreach ($ddl in $dynamicDLs) {
            try {
                $oldDisplayName = $ddl.DisplayName
                $newDisplayName = $ddl.Name
                Set-DynamicDistributionGroup -Identity $ddl.Identity -DisplayName $newDisplayName

                # Add the change to the array
                $results += [PSCustomObject]@{
                    Name           = $ddl.Name
                    OldDisplayName = $oldDisplayName
                    NewDisplayName = $newDisplayName
                }
            }
            catch {
                Write-Host "Failed to update DisplayName for $($ddl.Name): $_"
            }
        }

        # Export the results to a CSV file
        $results | Export-Csv -Path $outputCsv -NoTypeInformation
    }
    "S" {
        # Prompt the user for DDL
        $email = Read-Host "Enter the email address for the DDL you wish to update"
        $ddl = Get-DynamicDistributionGroup -Identity $email
        
        if ($null -ne $ddl) {
            try {
                $oldDisplayName = $ddl.DisplayName
                $newDisplayName = $ddl.Name
                Set-DynamicDistributionGroup -Identity $ddl.Identity -DisplayName $newDisplayName
            }
            catch {
                Write-Host "Failed to update DisplayName for $($ddl.Name): $_"
            }
        }
        else {
            Write-Host "No dynamic distribution group found for $email."
        }
    }

    "C" {
        # Define the path to the CSV file to import (Requires a column named 'Email')
        $inputCsv = Get-InputCsv

        # Define the path to the output CSV file where results will be saved
        $outputCsv = Get-OutputCsv

        # Create an array to store the changes
        $results = @()

        # Import the CSV file
        $dynamicDLs = Import-Csv -Path $inputCsv

        # Loop through each email in the CSV
        foreach ($email in $dynamicDLs) {
            $ddl = Get-DynamicDistributionGroup -Identity $email.Email
            
            if ($null -ne $ddl) {
                try {
                    $oldDisplayName = $ddl.DisplayName
                    $newDisplayName = $ddl.Name
                    Set-DynamicDistributionGroup -Identity $ddl.Identity -DisplayName $newDisplayName
            
                    # Add the change to the array
                    $results += [PSCustomObject]@{
                        Name           = $ddl.Name
                        OldDisplayName = $oldDisplayName
                        NewDisplayName = $newDisplayName
                    }
                }
                catch {
                    Write-Host "Failed to update DisplayName for $($ddl.Name): $_"
                }
            }
            else {
                Write-Host "No dynamic distribution group found for $($email.Email)."
            }
        }
            
        # Export the results to a CSV file
        $results | Export-Csv -Path $outputCsv -NoTypeInformation    
    }
}