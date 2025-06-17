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

# Check if the user is connected to Exchange Online
$getSessions = Get-ConnectionInformation | Select-Object Name
$isConnected = (@($getSessions.Name) -like 'ExchangeOnline*').Count -gt 0
If ($isConnected -ne 'True') {
    Connect-ExchangeOnline -ShowBanner:$false
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

# Prompt the user for the name of the dynamic distribution group
$dynamicGroupName = Read-Host -Prompt "Enter the name of the dynamic distribution group"

# Identify the dynamic distribution group
$dynamicGroup = Get-DynamicDistributionGroup -Identity $dynamicGroupName

# Retrieve the current membership
$members = Get-DynamicDistributionGroupMember -Identity $dynamicGroup.Identity

# Export the membership to a CSV file
$csvPath = Get-OutputCsv
$members | Select-Object DisplayName, PrimarySmtpAddress | Export-Csv -Path $csvPath -NoTypeInformation

# Inform the user of the export
Write-Host "The membership of the dynamic distribution group '$dynamicGroupName' has been exported to $csvPath"