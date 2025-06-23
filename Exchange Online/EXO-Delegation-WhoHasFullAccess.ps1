<#
.SYNOPSIS
    Check delegation permissions for mailboxes in Exchange Online.
.DESCRIPTION
    This script checks delegation permissions (Full Access, Send As, Send on Behalf Of) for mailboxes in Exchange Online.
    It can run for all users, a single user, or multiple users from a CSV file containing email addresses.
    The results are exported to a CSV file.
    The script requires appropriate permissions to read mailbox permissions in Exchange Online.
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

# Function to prompt for a valid choice
function Get-Choice {
    do {
        $choice = Read-Host "Do you want to run the script for (A)ll users, a (S)ingle user, or use a (C)SV of users? Enter A, S, or C (Note: 'All' will take F O R E V E R)"
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

# Prompt user for input
$choice = Get-Choice

# Execute based on user choice
switch ($choice) {
    "A" {
        # Define the path to the output CSV file where results will be saved
        $outputCSV = Get-OutputCsv

        # Get all mailboxes
        $mailboxes = Get-Mailbox -ResultSize Unlimited

        # Initialize an array to store permission results
        $results = @()

        # Loop through each mailbox
        foreach ($mailbox in $mailboxes) {
            $mailboxIdentity = $mailbox.PrimarySmtpAddress

            # Initialize a hashtable to store the permissions for the specified mailbox
            $mailboxPermissions = @{
                Mailbox        = $mailboxIdentity
                FullAccess     = @("None")
                SendAs         = @("None")
                SendOnBehalfTo = @("None")
            }

            try {
                # Check Full Access permissions
                $fullAccess = Get-MailboxPermission -Identity $mailboxIdentity -ErrorAction Stop | Where-Object { ($_.AccessRights -eq "FullAccess") -and ($_.IsInherited -eq $false) }
                if ($fullAccess) {
                    $mailboxPermissions.FullAccess = $fullAccess | Select-Object -ExpandProperty User
                }

                # Check Send As permissions
                $sendAs = Get-RecipientPermission -Identity $mailboxIdentity -ErrorAction Stop | Where-Object { $_.Trustee -ne "NT AUTHORITY\SELF" }
                if ($sendAs) {
                    $mailboxPermissions.SendAs = $sendAs | Select-Object -ExpandProperty Trustee
                }

                # Check Send on Behalf permissions
                $sendOnBehalf = Get-Mailbox -Identity $mailboxIdentity -ErrorAction Stop | Select-Object -ExpandProperty GrantSendOnBehalfTo
                if ($sendOnBehalf) {
                    $mailboxPermissions.SendOnBehalfTo = $sendOnBehalf
                }
            }
            catch {
                # Record the error if the mailbox is not found
                $mailboxPermissions = @{
                    Mailbox        = $mailboxIdentity
                    FullAccess     = @("Mailbox not found")
                    SendAs         = @("Mailbox not found")
                    SendOnBehalfTo = @("Mailbox not found")
                }
            }

            # Add the results to the array
            $results += [PSCustomObject]@{
                Mailbox        = $mailboxIdentity
                FullAccess     = [string]::Join(", ", $mailboxPermissions.FullAccess)
                SendAs         = [string]::Join(", ", $mailboxPermissions.SendAs)
                SendOnBehalfTo = [string]::Join(", ", $mailboxPermissions.SendOnBehalfTo)
            }
        }

        # Export the data to a CSV file
        $mailboxData | Export-Csv -Path $outputCSV -NoTypeInformation
    }
    "S" {
        # Prompt the user for a mailbox email address
        $mailbox = Read-Host "Enter the email address of the mailbox to check"

        # Initialize a hashtable to store the permissions for the specified mailbox
        $mailboxPermissions = @{
            Mailbox        = $mailbox
            FullAccess     = @()
            SendAs         = @()
            SendOnBehalfTo = @()
        }

        # Check Full Access permissions
        $fullAccess = Get-MailboxPermission -Identity $mailbox | Where-Object { ($_.AccessRights -eq "FullAccess") -and ($_.IsInherited -eq $false) }
        $mailboxPermissions.FullAccess = $fullAccess | Select-Object -ExpandProperty User

        # Check Send As permissions
        $sendAs = Get-RecipientPermission -Identity $mailbox | Where-Object { $_.Trustee -ne "NT AUTHORITY\SELF" }
        $mailboxPermissions.SendAs = $sendAs | Select-Object -ExpandProperty Trustee

        # Check Send on Behalf permissions
        $sendOnBehalf = Get-Mailbox -Identity $mailbox | Select-Object -ExpandProperty GrantSendOnBehalfTo
        $mailboxPermissions.SendOnBehalfTo = $sendOnBehalf

        # Display the results in the console
        Write-Host "Delegation permissions for mailbox: $mailbox"
        Write-Host "Full Access:"
        $mailboxPermissions.FullAccess | ForEach-Object { Write-Host "  - $_" }

        Write-Host "Send As:"
        $mailboxPermissions.SendAs | ForEach-Object { Write-Host "  - $_" }

        Write-Host "Send On Behalf Of:"
        $mailboxPermissions.SendOnBehalfTo | ForEach-Object { Write-Host "  - $_" }    
    }
    "C" {
        # Define the path to the CSV file containing the email addresses (Requires a column named 'Email')
        $inputCsv = Get-InputCsv

        # Define the path to the output CSV file where results will be saved
        $outputCsv = Get-OutputCsv

        # Import the CSV file containing email addresses
        $emails = Import-Csv -Path $inputCsv

        # Initialize an array to store permission results
        $results = @()

        # Loop through each email in the CSV
        foreach ($entry in $emails) {
            $mailbox = $entry.Email

            # Initialize a hashtable to store the permissions for the specified mailbox
            $mailboxPermissions = @{
                Mailbox        = $mailbox
                FullAccess     = @("None")
                SendAs         = @("None")
                SendOnBehalfTo = @("None")
            }

            try {
                # Check Full Access permissions
                $fullAccess = Get-MailboxPermission -Identity $mailbox -ErrorAction Stop | Where-Object { ($_.AccessRights -eq "FullAccess") -and ($_.IsInherited -eq $false) }
                if ($fullAccess) {
                    $mailboxPermissions.FullAccess = $fullAccess | Select-Object -ExpandProperty User
                }

                # Check Send As permissions
                $sendAs = Get-RecipientPermission -Identity $mailbox -ErrorAction Stop | Where-Object { $_.Trustee -ne "NT AUTHORITY\SELF" }
                if ($sendAs) {
                    $mailboxPermissions.SendAs = $sendAs | Select-Object -ExpandProperty Trustee
                }

                # Check Send on Behalf permissions
                $sendOnBehalf = Get-Mailbox -Identity $mailbox -ErrorAction Stop | Select-Object -ExpandProperty GrantSendOnBehalfTo
                if ($sendOnBehalf) {
                    $mailboxPermissions.SendOnBehalfTo = $sendOnBehalf
                }
            }
            catch {
                # Record the error if the mailbox is not found
                $mailboxPermissions = @{
                    Mailbox        = $mailbox
                    FullAccess     = @("Mailbox not found")
                    SendAs         = @("Mailbox not found")
                    SendOnBehalfTo = @("Mailbox not found")
                }
            }

            # Add the results to the array
            $results += [PSCustomObject]@{
                Mailbox        = $mailbox
                FullAccess     = [string]::Join(", ", $mailboxPermissions.FullAccess)
                SendAs         = [string]::Join(", ", $mailboxPermissions.SendAs)
                SendOnBehalfTo = [string]::Join(", ", $mailboxPermissions.SendOnBehalfTo)
            }
        }

        # Export the results to a CSV file
        $results | Export-Csv -Path $outputCsv -NoTypeInformation    
    }
}