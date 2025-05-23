# Construct the URL for the blob
$imageUrl = "ADD URL HERE.jpg"

# Use Invoke-WebRequest to download the image
Invoke-WebRequest -Uri $ImageUrl -OutFile "$env:TEMP\background.jpg"

# Set the downloaded image as the desktop background
Set-ItemProperty -Path 'HKCU:\Control Panel\Desktop\' -Name Wallpaper -Value "$env:TEMP\background.jpg"

# Refresh the desktop to apply the changes
RUNDLL32.EXE user32.dll,UpdatePerUserSystemParameters