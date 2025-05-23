#Grabs the installed teamviewer registry keys from either 32bit or 64 bit locations.
$Teamviewer32 = Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\uninstall\*' -ErrorAction SilentlyContinue | Where-Object { ((Get-ItemProperty -Path $_.PsPath) -match 'TeamViewer') }
$Teamviewer64 = Get-ItemProperty -Path 'HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\uninstall\*' -ErrorAction SilentlyContinue | Where-Object { ((Get-ItemProperty -Path $_.PsPath) -match 'TeamViewer') }
$Teamviewer32Path = $null -ne $Teamviewer32 -and ( Test-Path -Path $Teamviewer32.pspath)
$Teamviewer64Path = $null -ne $Teamviewer64 -and ( Test-Path -Path $Teamviewer64.pspath)

#tries to uninstall 32 bit, then install latest version.
if ($Teamviewer32path -eq $true) {
    start-process $Teamviewer32.UninstallString -ArgumentList '/S' -Wait
}
else { write-host "32 bit not installed" }
#tries to uninstall 64 bit, then install latest version.
If ($Teamviewer64Path -eq $true) {
    start-process $Teamviewer64.UninstallString -ArgumentList '/S' -Wait
}
else { Write-Host "64 bit not installed" }