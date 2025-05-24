If([String](Get-Item -Path "$Env:ProgramFiles\Google\Chrome\Application\chrome.exe","${Env:ProgramFiles(x86)}\Google\Chrome\Application\chrome.exe" -ErrorAction SilentlyContinue).VersionInfo.FileVersion -ge "117.0.5938.150"){
Write-Host "Installed"
Exit 0
}
else {
Exit 1
}
