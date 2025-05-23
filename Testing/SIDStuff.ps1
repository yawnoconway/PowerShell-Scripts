# Replace this with the actual SID of the user
$UserSID = 'S-1--12-1-1773036090-1124400513-4081965969-3897465319'

# Retrieve the username associated with the SID
$user = Get-WmiObject Win32_UserAccount | Where-Object { $_.SID -eq $UserSID }

if ($user) {
    # Display the user account info
    Write-Output "Found User: $($user.Name)"

    # Define the new password
    $newPassword = 'Visor6025dimer'  # Replace with your desired password

    # Reset the password
    try {
        net user $user.Name $newPassword
        Write-Output "Password for user $($user.Name) has been reset successfully."
    } catch {
        Write-Output "Failed to reset password: $_"
    }
} else {
    Write-Output "No user found with SID $UserSID"
}
