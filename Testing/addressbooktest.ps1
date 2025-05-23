# Create an Outlook application object
$Outlook = New-Object -ComObject Outlook.Application

# Get the MAPI namespace
$Namespace = $Outlook.GetNamespace("MAPI")

# Find the default Global Address List (GAL)
$GAL = $null
foreach ($addressList in $Namespace.AddressLists) {
    if ($addressList.AddressListType -eq "olDefaultGlobalAddressList") {
        $GAL = $addressList
        break
    }
}

# Check if the GAL is found
if ($null -eq $GAL) {
    Write-Host "Default Global Address List not found."
    return
}

# Get the synchronization object for the GAL and start synchronization
$SyncObject = $Namespace.SyncObjects | Where-Object { $_.Name -eq $GAL.EntryID }
$SyncObject.Start()

# Wait for the synchronization process to complete
while ($SyncObject.SyncState -ne "olSyncStopped") {
    Start-Sleep -Milliseconds 100
}

# Release the Outlook objects
[System.Runtime.Interopservices.Marshal]::ReleaseComObject($SyncObject) | Out-Null
[System.Runtime.Interopservices.Marshal]::ReleaseComObject($GAL) | Out-Null
[System.Runtime.Interopservices.Marshal]::ReleaseComObject($Namespace) | Out-Null
[System.Runtime.Interopservices.Marshal]::ReleaseComObject($Outlook) | Out-Null
