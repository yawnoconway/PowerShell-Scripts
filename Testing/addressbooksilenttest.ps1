$olApp = Get-Process | Where-Object { $_.ProcessName -eq "OUTLOOK" }

if (!$olApp) {
    $outlook = New-Object -ComObject Outlook.Application
} else {
    $outlook = [System.Runtime.InteropServices.Marshal]::GetActiveObject("Outlook.Application")
}

$namespace = $outlook.GetNamespace("MAPI")
$syncObjects = $namespace.SyncObjects

foreach ($syncObject in $syncObjects) {
    if ($syncObject.SyncStatus -eq 2) {
        $syncObject.Start()
    }
}

# Wait for the synchronization to complete
do {
    Start-Sleep -Milliseconds 100
} until ($syncObjects.SyncObjects | Where-Object { $_.SyncStatus -eq 2 })
