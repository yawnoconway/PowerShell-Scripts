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
        $mailboxes = 

        # Loop through each mailbox
        foreach ($mailbox in $mailboxes) {
            try {
                
            }
            catch {
                
            }
        }

        # Export the data to a CSV file
        $mailboxData | Export-Csv -Path $outputCSV -NoTypeInformation
    }
    "S" {
        # Prompt the user for
        $prompt = Read-Host ""

    }
    "C" {
        # Define the path to the CSV file containing the email addresses (Requires a column named 'Email')
        $inputCsv = Get-InputCsv

        # Define the path to the output CSV file where results will be saved
        $outputCsv = Get-OutputCsv

        # Import the CSV file
        $import = Import-Csv -Path $inputCsv

        # Loop through each email in the CSV
        foreach ($entry in $import) {
            try {
                
            }
            catch {
                
            }
        }

        # Export the results to a CSV file
        $results | Export-Csv -Path $outputCsv -NoTypeInformation    
    }
}