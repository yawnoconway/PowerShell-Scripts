Write-Host "This script will Mail-Enable a single, specific user.  This will usually be for a specific user that you have just created."  
Write-Host "  "
Write-Host "When prompted, simply provide the Username for the specific user. " 
Write-Host "  "

$user = Read-Host "Enter Username for User (e.g. first.last): "

$upn = $user+"@DOMAIN.com"

$RRA = $user+"@DOMAIN.mail.onmicrosoft.com"

Enable-RemoteMailbox $upn -RemoteRoutingAddress $RRA