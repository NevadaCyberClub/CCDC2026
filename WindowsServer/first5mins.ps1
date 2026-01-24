Import-Module -Name ActiveDirectory
Import-Module -Name GroupPolicy

#placing this first because UCI
# Disable SMBv1
Write-Output "Disabling SMBv1"
try {
    Set-SmbServerConfiguration -EnableSMB1Protocol $false
}
catch {
    Write-Output "Failed to disable SMBv1! This is a critical security vulnerability!"
}

# enable Kerberos Pre-Authentication for all users
# Write-Output "Enabling Kerberos Pre-Authentication for all users"
# try {
#     Set-ADDefaultDomainPasswordPolicy -PreAuthNotRequired $false
#     Get-ADUser -Filter {DoesNotRequirePreAuth -eq $true} | Set-ADUser -DoesNotRequirePreAuth $false -Confirm:$false
# }
# catch {
#     Write-Output "Failed to enable Kerberos Pre-Authentication for all users!"
# }

# Disable Spooler Service
Write-Output "Disabling Print Spooler service"
try {
    Stop-Service -Name "Spooler" -ErrorAction Stop
    Set-Service -Name "Spooler" -StartupType Disabled
}
catch {
    Write-Host "Failed to disable Print Spooler service!"
}

# Mitigate ZeroLogon
Write-Output "Mitigating ZeroLogon"

Write-Output "Enabling enforcement of netlogon secure channel"
try {
    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\Netlogon\Parameters" -Name "FullSecureChannelProtection" -Value 1 -Type DWord
}
catch {
    Write-Output "Failed to enable enforcement of netlogon secure channel!"
}

Write-Output "Removing vulnerable channel allow list"
$vulAllows = Test-Path -Path "HKLM:\SYSTEM\CurrentControlSet\Services\Netlogon\Parameters\VulnerableChannelAllowList"
if ($vulAllows) {
    Remove-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\Netlogon\Parameters\VulnerableChannelAllowList" -Name "VulnerableChannelAllowList" -Force
    Write-Output "Removed vulnerable channel allow list"
} else {
    Write-Output "Vulnerable channel allow list does not exist"
}

# Mitigate noPac
Write-Output "Mitigating noPac"
try {
    # dissallow users from setting their own machine account password
    # Set-ADDomain -Identity $env:USERDNSDOMAIN -replace @{"ms-DS-MachineAccountQuota"="0"}
    Set-ADDomain (Get-ADDomain).distinguishedname -Replace @{"ms-ds-MachineAccountQuota"="0"}
} catch {
    Write-Output "Failed to mitigate noPac!"
}


# Ensure NuGet is installed
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
[Net.ServicePointManager]::SecurityProtocol

#place .nupkg in C:\Program Files\WindowsPowerShell\Modules
Invoke-WebRequest -Uri "https://psg-prod-eastus.azureedge.net/packages/packagemanagement.1.1.0.nupkg" -OutFile "C:\Program Files\WindowsPowerShell\Modules\packagemanagement.1.1.0.nupkg"

# Install-Module -Name PackageManagement -RequiredVersion 1.1.0.0

Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force -Confirm:$false

Register-PSRepository -Default -InstallationPolicy Trusted

#Install and apply modules
Install-Module -Name PSWindowsUpdate -Force -Confirm:$false

Import-Module -Name PSWindowsUpdate

Write-Output "Making C:\tmp directory and C:\tmp\gpos directory"
#Make C:\tmp directory
New-Item -Path "C:\tmp" -ItemType Directory

#Make C:\tmp\gpos directory
New-Item -Path "C:\tmp\gpos" -ItemType Directory

# Change Administrator password
$password = Read-Host -AsSecureString "Enter new administrator password: "
Set-LocalUser -Name Administrator -Password $password

# Make backup Admin account
New-ADUSer  -Name "Inconspicious User" `
            -SamAccountName "iuser" `
            -UserPrincipalName "iuser@$env:USERDNSDOMAIN" `
            -AccountPassword $password `
            -Enabled $true

#Disable Guest Account
Write-Output "Disabling Guest Account"
Set-ADUser -Identity "Guest" -Enabled $false
Set-LocalUser -Name Guest -Enabled $false

# Get Default Naming Context
$defaultNamingContext = (Get-ADRootDSE).defaultNamingContext

# Add backup Admin to Domain Admins, Enterprise Admins, Schema Admins, Administrators, DNSADmins, and Remote Desktop Users
Add-ADGroupMember -Identity "Domain Admins" -Members "iuser"
Add-ADGroupMember -Identity "Enterprise Admins" -Members "iuser"
Add-ADGroupMember -Identity "Schema Admins" -Members "iuser"
Add-ADGroupMember -Identity "Administrators" -Members "iuser"
Add-LocalGroupMember -Group "Administrators" -Member "iuser"
Add-ADGroupMember -Identity "DNSAdmins" -Members "iuser"
Add-ADGroupMember -Identity "Remote Desktop Users" -Members "iuser"

# Remove all Users from Domain Admins, Enterprise Admins, Schema Admins, Administrators, and Remote Desktop Users except for the backup admin and the built-in admin
$domainAdmins = Get-ADGroupMember -Identity "Domain Admins" | Where-Object { $_.SamAccountName -ne "Administrator" -and $_.SamAccountName -ne "iuser" }
$enterpriseAdmins = Get-ADGroupMember -Identity "Enterprise Admins" | Where-Object { $_.SamAccountName -ne "Administrator" -and $_.SamAccountName -ne "iuser" }
$schemaAdmins = Get-ADGroupMember -Identity "Schema Admins" | Where-Object { $_.SamAccountName -ne "Administrator" -and $_.SamAccountName -ne "iuser" }
$administrators = Get-ADGroupMember -Identity "Administrators" | Where-Object { $_.SamAccountName -ne "Administrator" -and $_.SamAccountName -ne "iuser" }
$localAdministrators = Get-LocalGroupMember -Group "Administrators" | Where-Object { $_.Name -ne "Administrator" -and $_.Name -ne "iuser" }
$dnsAdmins = Get-ADGroupMember -Identity "DNSAdmins" | Where-Object { $_.SamAccountName -ne "Administrator" -and $_.SamAccountName -ne "iuser" }
$remoteDesktopUsers = Get-ADGroupMember -Identity "Remote Desktop Users" | Where-Object { $_.SamAccountName -ne "Administrator" -and $_.SamAccountName -ne "iuser" }

# Write the removed users to a file

$oldDomainAdminsFile = "C:\tmp\oldDomainAdmins.txt"
foreach ($user in $domainAdmins) {
    Remove-ADGroupMember -Identity "Domain Admins" -Members $user -Confirm:$false
    Add-Content -Path $oldDomainAdminsFile -Value $user.SamAccountName
}
$oldEnterpriseAdminsFile = "C:\tmp\oldEnterpriseAdmins.txt"
foreach ($user in $enterpriseAdmins) {
    Remove-ADGroupMember -Identity "Enterprise Admins" -Members $user -Confirm:$false
    Add-Content -Path $oldEnterpriseAdminsFile -Value $user.SamAccountName
}
$oldSchemaAdminsFile = "C:\tmp\oldSchemaAdmins.txt"
foreach ($user in $schemaAdmins) {
    Remove-ADGroupMember -Identity "Schema Admins" -Members $user -Confirm:$false
    Add-Content -Path $oldSchemaAdminsFile -Value $user.SamAccountName
}
$oldAdministratorsFile = "C:\tmp\oldAdministrators.txt"
foreach ($user in $administrators) {
    Remove-ADGroupMember -Identity "Administrators" -Members $user -Confirm:$false
    Add-Content -Path $oldAdministratorsFile -Value $user.SamAccountName
}
$oldLocalAdministratorsFile = "C:\tmp\oldLocalAdministrators.txt"
foreach ($user in $localAdministrators) {
    Remove-LocalGroupMember -Group "Administrators" -Member $user.Name
    Add-Content -Path $oldLocalAdministratorsFile -Value $user.Name
}
$oldDnsAdminsFile = "C:\tmp\oldDnsAdmins.txt"
foreach ($user in $dnsAdmins) {
    Remove-ADGroupMember -Identity "DNSAdmins" -Members $user -Confirm:$false
    Add-Content -Path $oldDnsAdminsFile -Value $user.SamAccountName
}
$oldRemoteDesktopUsersFile = "C:\tmp\oldRemoteDesktopUsers.txt"
foreach ($user in $remoteDesktopUsers) {
    Remove-ADGroupMember -Identity "Remote Desktop Users" -Members $user -Confirm:$false
    Add-Content -Path $oldRemoteDesktopUsersFile -Value $user.SamAccountName
}

#Backup GPOs
Backup-GPO -All -Path "C:\tmp\gpos"

#Backup AD
$backupPath = "C:\tmp\ADBackup"
New-Item -Path $backupPath -ItemType Directory
ntdsutil "activate instance ntds" "ifm" "create full $backupPath" "quit" "quit"

#Remove all GPOs
Get-GPO -All | Remove-GPO -Confirm:$false

#Unlink default domain policy and default domain controller policy
Get-GPO -All | Where-Object { $_.DisplayName -eq "Default Domain Policy" -or $_.DisplayName -eq "Default Domain Controllers Policy" } | ForEach-Object { $_ | Remove-GPLink -Target "dc=$env:USERDNSDOMAIN" }

Remove-GPLink -Name "Default Domain Policy" -Target "dc=$env:USERDNSDOMAIN" -LinkEnabled Yes

Remove-GPLink -Name "Default Domain Controllers Policy" -Target "ou=dc=$env:USERDNSDOMAIN" -LinkEnabled Yes

#Remake default domain policy and default domain controller policy
New-GPO -Name "Default Domain Policy" -Comment "Default Domain Policy" | New-GPLink -Target "dc=$env:USERDNSDOMAIN" -LinkEnabled Yes
New-GPO -Name "Default Domain Controllers Policy" -Comment "Default Domain Controllers Policy" | New-GPLink -Target "dc=$env:USERDNSDOMAIN" -LinkEnabled Yes
dcgpofix /ignoreschema /target:both

#Attempt DNS Backup
$dnsBackupPath = "C:\tmp\DNSBackup"
New-Item -Path $dnsBackupPath -ItemType Directory
dnscmd /enumzones > $dnsBackupPath\zones.txt
foreach ($zone in Get-Content $dnsBackupPath\zones.txt | Where-Object { $_ -match "Zone name" }) {
    $zoneName = $zone -replace ".*: ", ""
    dnscmd /zoneexport $zoneName $dnsBackupPath\$zoneName.bak
}

# Enable Windows Firewall
Set-NetFirewallProfile -Profile Domain,Public,Private -Enabled True

# Enable Remote Desktop
Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server' -name "fDenyTSConnections" -value 0

# Enable Remote Desktop Firewall Rule
Enable-NetFirewallRule -DisplayGroup "Remote Desktop"

# Add Administrator and iuser to Remote Desktop Users
Add-LocalGroupMember -Group "Remote Desktop Users" -Member "Administrator"
Add-LocalGroupMember -Group "Remote Desktop Users" -Member "iuser"

# Enable Windows Defender
Set-MpPreference -DisableRealtimeMonitoring $false
Set-MpPreference -DisableBehaviorMonitoring $false
Set-MpPreference -DisableBlockAtFirstSeen $false
Set-MpPreference -HighThreatDefaultAction 6
Set-MpPreference -ModerateThreatDefaultAction 6
Set-MpPreference -LowThreatDefaultAction 6
Set-MpPreference -SevereThreatDefaultAction 6
Set-MpPreference -PUAProtection 1

#Get User Accounts that are used as Service Accounts
Get-ADUser -Filter {ServicePrincipalName -ne "$null"} -Properties ServicePrincipalName

#Disable Windows Remote Management
Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WinRM\Client" -Name "AllowBasic" -Value 0 -Type DWord
Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WinRM\Client" -Name "AllowUnencryptedTraffic" -Value 0 -Type DWord
Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WinRM\Client" -Name "AllowDigest" -Value 0 -Type DWord
Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WinRM\Client" -Name "AllowKerberos" -Value 0 -Type DWord
Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WinRM\Client" -Name "AllowNegotiate" -Value 0 -Type DWord
Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WinRM\Client" -Name "AllowCertificate" -Value 0 -Type DWord
Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WinRM\Client" -Name "AllowCredSSP" -Value 0 -Type DWord
Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WinRM\Client" -Name "AllowBasic" -Value 0 -Type DWord
Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WinRM\Client" -Name "AllowRemoteShellAccess" -Value 0 -Type DWord
Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WinRM\Client" -Name "AllowAutoConfig" -Value 0 -Type DWord

#Disable PSRemoting
Disable-PSRemoting -Force

# Disable Windows Remote Management Service
Stop-Service -Name WindowsRemoteManagement -Force
Set-Service -Name WindowsRemoteManagement -StartupType Disabled

# Only allow remote access to members of Administrators group
Write-Output "Only allowing remote access to members of Administrators group"
try {
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -Name "LocalAccountTokenFilterPolicy" -Value 0 -Type DWord
} catch {
    Write-Output "Failed to only allow remote access to members of Administrators group!"
}

# Disable LLMNR
Write-Output "Disabling LLMNR"
try {
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\DNSClient" -Name "EnableMulticast" -Value 0 -Type DWord
} catch {
    Write-Output "Failed to disable LLMNR!"
}

# Disable NetBIOS
Write-Output "Disabling NetBIOS and LMHOSTS"
try {
    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\NetBT\Parameters" -Name "EnableNetbios" -Value 0 -Type DWord
    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\NetBT\Parameters" -Name "EnableLmhosts" -Value 0 -Type DWord
} catch {
    Write-Output "Failed to disable NetBIOS!"
}

# Disable WPAD
Write-Output "Disabling WPAD"
try {
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\CurrentVersion\Internet Settings" -Name "EnableAutoproxyResultCache" -Value 0 -Type DWord
}
catch {
    Write-Output "Failed to disable WPAD!"
}

# Disable AppLocker (counter trolling)
Write-Output "Disabling AppLocker"
try{
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\SrpV2" -Name "EnforcementMode" -Value 0 -Type DWord
}
catch {
    Write-Output "Failed to disable AppLocker!"
}

#list shadow copies
vssadmin list shadows

Write-Output "Enabling SMB Encryption"
Set-SmbServerConfiguration -EncryptData $true -Confirm:$false

#MORE MITIGATIONS, FROM WGU's deepend.ps1 script

#Disable SMB null sessions
Write-Output "Disabling SMB null sessions."
try {
    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters" -Name "RestrictNullSessAccess" -Value 1 -Type DWord
}
catch {
    Write-Output "Failed to disable SMB null sessions."
}
Write-Output "Disabling Anonymous access"
try {
    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa" -Name "RestrictAnonymous" -Value 1 -Type DWord
    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa" -Name "RestrictAnonymousSAM" -Value 1 -Type DWord
    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa" -Name "EveryoneIncludesAnonymous" -Value 0 -Type DWord
}
catch {
    Write-Output "Failed to disable Anonymous enumeration of SAM accounts."
}

#Harden LSA to protect from mimikatz etc
Write-Output "Enabling protections for LSA"
Write-Output "This will require a reboot"
try {
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options" -name "AuditLevel" -Type DWORD -Value 8 -Force
} catch {
    Write-Output "Failed to enable protections for LSA"
}

Write-Output "Enabling PPL for LSA"
Write-Output "This will require a reboot"
try {
    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa" -name "RunAsPPL" -Type DWORD -Value 1 -Force
} catch {
    Write-Output "Failed to enable PPL for LSA"
}

#disable wdigest
Write-Output "Disabling wdigest"
try {
    New-Item -Path "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders" -Name "WDigest"
    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\WDigest" -name "UseLogonCredential" -Type DWORD -Value 0 -Force
} catch {
    Write-Output "Failed to disable wdigest"
}

#disable ntlm
Write-Output "Disabling ntlm"
try {
    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa" -name "lmcompatibilitylevel" -Type DWORD -Value 5 -Force
} catch {
    Write-Output "Failed to disable ntlm"
}


New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\" -Name "CredentialsDelegation"
Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\CredentialsDelegation" -name "AllowProtectedCreds" -Type DWORD -Value 1 -Force

#disable netbios over tcp/ip and lmhosts lookups
$nics = Get-WmiObject win32_NetworkAdapterConfiguration
foreach ($nic in $nics) {
    $nic.settcpipnetbios(2) # 2 = disable netbios on interface
    # $nic.enablewins($false,$false) #disable wins
}
#enable powershell logging
Write-Output "Enabling powershell logging"
try {
    reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\PowerShell\ModuleLogging" /v EnableModuleLogging /t REG_DWORD /d 1 /f
}
catch {
    Write-Output "Failed to enable powershell module logging"
}

# enable script block logging
Write-Output "Enabling powershell script block logging"
try {
    reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\PowerShell\ScriptBlockLogging" /v EnableScriptBlockLogging /t REG_DWORD /d 1 /f
}
catch {
    Write-Output "Failed to enable powershell script block logging"
}

# enable powershell transcription
Write-Output "Enabling powershell transcription"
try {
    reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\PowerShell\Transcription" /v EnableTranscripting /t REG_DWORD /d 1 /f
}
catch {
    Write-Output "Failed to enable powershell transcription"
}

# enable powershell constrained language mode
Write-Output "Enabling powershell constrained language mode"
try {
    reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\PowerShell" /v EnableTranscripting /t REG_DWORD /d 1 /f
}
catch {
    Write-Output "Failed to enable powershell constrained language mode"
}

#Disable SMB Compression
#https://msrc.microsoft.com/update-guide/en-US/vulnerability/CVE-2020-0796
Write-Output "Disabling SMB Compression for CVE 2020-0796"
try {
    reg add "HKLM\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters" /v DisableCompression /t REG_DWORD /d 1 /f
}
catch {
    Write-Output "Failed to disable SMB Compression"
}

## Appended more stuff cuz why not
# Author: Christopher Goes

# The following comes from this gist: https://gist.github.com/alirobe/7f3b34ad89a159e6daa1
# Which was derived from here: https://github.com/Disassembler0/Win10-Initial-Setup-Script/
# Raise UAC level
Write-Host "Raising UAC level..."
try {
    Set-ItemProperty -Path "HKLM:\Software\Microsoft\Windows\CurrentVersion\Policies\System" -Name "ConsentPromptBehaviorUser" -Type DWord -Value 0
    Set-ItemProperty -Path "HKLM:\Software\Microsoft\Windows\CurrentVersion\Policies\System" -Name "EnableLUA" -Type DWord -Value 1
    Set-ItemProperty -Path "HKLM:\Software\Microsoft\Windows\CurrentVersion\Policies\System" -Name "ConsentPromptBehaviorAdmin" -Type DWord -Value 5
    Set-ItemProperty -Path "HKLM:\Software\Microsoft\Windows\CurrentVersion\Policies\System" -Name "PromptOnSecureDesktop" -Type DWord -Value 1
}
catch {
    Write-Host "Failed to raise UAC level."
}

# Disable sharing mapped drives between users
Write-Host "Disabling sharing mapped drives between users..."
try {
    Set-ItemProperty -Path "HKLM:\Software\Microsoft\Windows\CurrentVersion\Policies\System" -Name "EnableLinkedConnections" -Type DWord -Value 0
}
catch {
    Write-Host "Failed to disable sharing mapped drives between users."
}

# Stop and disable Home Groups services
Write-Host "Stopping and disabling Home Groups services..."
try {
    Stop-Service "HomeGroupListener"
    Set-Service "HomeGroupListener" -StartupType Disabled
    Stop-Service "HomeGroupProvider"
    Set-Service "HomeGroupProvider" -StartupType Disabled
}
catch {
    Write-Host "Failed to stop and disable Home Groups services."
}

# Disable Remote Assistance
Write-Host "Disabling Remote Assistance..."
try {
    Set-ItemProperty -Path "HKLM:\System\CurrentControlSet\Control\Remote Assistance" -Name "fAllowToGetHelp" -Type DWord -Value 0
}
catch {
    Write-Host "Failed to disable Remote Assistance."
}

# Disable Autoplay
Write-Host "Disabling Autoplay..."
try {
    Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\AutoplayHandlers" -Name "DisableAutoplay" -Type DWord -Value 1
}
catch {
    Write-Host "Failed to disable Autoplay."
}

#Disable Sticky keys prompt
Write-Host "Disabling Sticky keys prompt..."
try {
    Set-ItemProperty -Path "HKCU:\Control Panel\Accessibility\StickyKeys" -Name "Flags" -Type String -Value "506"
}
catch {
    Write-Host "Failed to disable Sticky keys prompt."
}

# Show hidden files
Write-Host "Showing hidden files..."
try {
    Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "Hidden" -Type DWord -Value 1
}
catch {
    Write-Host "Failed to show hidden files."
}

#snippet from from: https://github.com/WGU-CCDC/Blue-Team-Tools/blob/main/Windows/deepend.ps1

Write-Output "Adding outbound rules to prevent LOLBins."
#add rules to prevent lolbins outbound
$Params = @{ "DisplayName" = "WGU-Block Network Connections-Notepad.exe"
    "Direction"            = "Outbound"
    "Action"               = "Block"
    "Program"              = "%systemroot%\system32\notepad.exe"
}
New-NetFirewallRule @params
$Params = @{ "DisplayName" = "WGU-Block Network Connections-regsvr32.exe"
    "Direction"            = "Outbound"
    "Action"               = "Block"
    "Program"              = "%systemroot%\system32\regsvr32.exe"
}
New-NetFirewallRule @Params
$Params = @{ "DisplayName" = "WGU-Block Network Connections-calc.exe"
    "Direction"            = "Outbound"
    "Action"               = "Block"
    "Program"              = "%systemroot%\system32\calc.exe"
}
New-NetFirewallRule @Params
$Params = @{ "DisplayName" = "WGU-Block Network Connections-mshta.exe"
    "Direction"            = "Outbound"
    "Action"               = "Block"
    "Program"              = "%systemroot%\system32\mshta.exe"
}
New-NetFirewallRule @Params
$Params = @{ "DisplayName" = "WGU-Block Network Connections-wscript.exe"
    "Direction"            = "Outbound"
    "Action"               = "Block"
    "Program"              = "%systemroot%\system32\wscript.exe"
}
New-NetFirewallRule @Params
$Params = @{ "DisplayName" = "WGU-Block Network Connections-cscript.exe"
    "Direction"            = "Outbound"
    "Action"               = "Block"
    "Program"              = "%systemroot%\system32\cscript.exe"
}
New-NetFirewallRule @Params
$Params = @{ "DisplayName" = "WGU-Block Network Connections-runscripthelper.exe"
    "Direction"            = "Outbound"
    "Action"               = "Block"
    "Program"              = "%systemroot%\system32\runscripthelper.exe"
}
New-NetFirewallRule @Params
$Params = @{ "DisplayName" = "WGU-Block Network Connections-regsvr32.exe"
    "Direction"            = "Outbound"
    "Action"               = "Block"
    "Program"              = "%systemroot%\system32\regsvr32.exe"
}

Get-ADComputer -Filter {OperatingSystem -Like "*Windows Server*"} | ForEach-Object {
    Start-Process -FilePath "cmd.exe" -ArgumentList ("/c nltest /sc_query:" + $_.Name) -Wait
}

#Install Windows Updates
Get-WindowsUpdate -Install -AcceptAll