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

# Define the input CSV file and the output CSV file
$inputCsvFile = 'group.csv'
$outputCsvFile = 'group2.csv'

# Read the content of the CSV file
$content = Get-Content -Path $inputCsvFile

# Create an empty array to hold the new rows
$newRows = @()

# Iterate over each line in the content
foreach ($line in $content) {
    # Split the line by comma
    $values = $line -split ","
    # Add each value as a new row to the array
    foreach ($value in $values) {
        $newRows += $value
    }
}

# Write the new rows to the output CSV file
$newRows | Out-File -FilePath $outputCsvFile -Encoding UTF8