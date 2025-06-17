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

Connect-ExchangeOnline

Import-Csv -Path "BulkContacts.csv" | ForEach-Object {
    New-MailContact -Name $_.DisplayName `
        -ExternalEmailAddress $_.ExternalEmailAddress `
        -FirstName $_.FirstName `
        -LastName $_.LastName `
        -Alias $_.Alias
}