Write-Host "This script will Mail-Enable a single, specific user.  This will usually be for a specific user that you have just created."  
Write-Host "  "
Write-Host "When prompted, simply provide the SamAccountName for the specific user. " 
Write-Host "  "

$sam = Read-Host "Enter SamAccountName for User: "

$upn = $sam+"@literams.net"

$RRA = $sam+"@literams.mail.onmicrosoft.com"

Enable-RemoteMailbox $upn -RemoteRoutingAddress $RRA