function ShowNedry {
    # Call FunctionB as a job so it runs "simultaneously"
    Start-Job -ScriptBlock ${function:PlayNedry} | Out-Null

    # Infinite loop
    while($true) {
    Write-Host "*Insert Nedry wagging his finger*"
    # Repeat the quote every 2 seconds infinitely
    while ($true) {
        Write-Host "Ah Ah Ah, you didn't say the magic word!"
        Start-Sleep -Seconds 1
    }
    }
}

function PlayNedry {
    $filePath = "C:\Users\josh.conway\Downloads\AhAhAh.mp4"
    $vlcPath = "C:\Program Files\VideoLAN\VLC\vlc.exe"

    if (Test-Path $filePath) {
        & $vlcPath --loop $filePath
    }
    else {
        Write-Host "File not found: $filePath"
    }
}

# Call FunctionA
ShowNedry