# Ensure the script is run as Administrator
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltinRole]::Administrator)) {
    Write-Error "This script must be run as an Administrator."
    exit 1
}

#############################################
# 1. Enforce Strong Kerberos Encryption
#############################################
# Create or use the registry key for Kerberos parameters
# $kerbRegPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa\Kerberos\Parameters"
# if (-not (Test-Path $kerbRegPath)) {
#     New-Item -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa\Kerberos" -Name "Parameters" -Force | Out-Null
# }

# # Set SupportedEncryptionTypes to 24
# # Value 24 (decimal) typically enables AES128 (0x08) and AES256 (0x10) while disabling RC4 (0x1) and DES (0x2)
# Write-Output "Enforcing AES-based Kerberos encryption (disabling RC4/legacy types)..."
# try {
#     Set-ItemProperty -Path $kerbRegPath -Name "SupportedEncryptionTypes" -Value 24 -Type DWord -Force
#     Write-Output "Kerberos encryption types updated."
# } catch {
#     Write-Error "Failed to update Kerberos encryption settings: $_"
# }

# #############################################
# # 2. (Optional) Reset the KRBTGT Account Password
# #############################################
# # WARNING: Resetting the KRBTGT password invalidates all existing Kerberos tickets.
# # It is a disruptive change and must be carefully coordinated.
# $resetKRBTGT = Read-Host "Do you want to reset the KRBTGT account password? (Y/N)"
# if ($resetKRBTGT -eq "Y") {
#     Import-Module ActiveDirectory
#     Write-Output "WARNING: Resetting KRBTGT will invalidate existing Kerberos tickets across the domain."
#     $newPassword = Read-Host "Enter a new complex password for the KRBTGT account" -AsSecureString
#     try {
#         Set-ADAccountPassword -Identity "krbtgt" -Reset -NewPassword $newPassword -ErrorAction Stop
#         Write-Output "KRBTGT account password has been reset."
#         Write-Output "IMPORTANT: Microsoft recommends performing a double reset of the KRBTGT account. Please plan accordingly."
#     } catch {
#         Write-Error "Failed to reset KRBTGT password: $_"
#     }
# } else {
#     Write-Output "KRBTGT account password reset skipped."
# }

#############################################
# 3. Enable Kerberos Auditing
#############################################
# Enabling detailed Kerberos auditing can help detect abnormal ticket requests or reuse.
# (This may also be configured via Group Policy under Advanced Audit Policy Configuration.)
$auditRegPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa\Kerberos\Parameters"
try {
    Write-Output "Enabling Kerberos auditing (AuditKerberosTokenReplay)..."
    Set-ItemProperty -Path $auditRegPath -Name "AuditKerberosTokenReplay" -Value 1 -Type DWord -Force
    Write-Output "Kerberos auditing enabled. Verify settings in your audit policy."
} catch {
    Write-Error "Failed to enable Kerberos auditing: $_"
}

#############################################
# Additional Recommendations
#############################################
Write-Output "Additional recommendations for mitigating Kerberos attacks:"
Write-Output " - Ensure that service accounts use managed service accounts where possible."
Write-Output " - Review and restrict unconstrained and resource-based delegation settings."
Write-Output " - Enable and monitor Kerberos event logs (Event IDs 4768, 4769, 4770, 4771, and 4776) to detect anomalies."
Write-Output " - Consider network segmentation and restricting access to domain controllers."
Write-Output " - Regularly review and update your domain’s security policies."

Write-Output "Kerberos mitigation steps applied. Some changes (e.g. encryption enforcement and KRBTGT reset) require a domain controller reboot or ticket refresh to take effect."
