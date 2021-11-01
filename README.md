# NIM-Conn-System-PowerShell-Skyward-SMS2.0

<p align="center">
  <img src="Assets/Logo.jpg">
</p>
NIM Connector for Skyward SMS 2.0

<!-- TABLE OF CONTENTS -->
## Table of Contents
* [Requirements](#Requirements)
* [Sample VPN Scripts](#sample-vpn-scripts)

## Requirements
- Progress OpenEdge Driver 11.7+ (ODBC)
  -- https://support.skyward.com/DeptDocs/Corporate/IT%20Services/Public%20Website/Technical%20Information/PaCInstallDocs/Skyward%20ODBC%20Launch%20Kit.pdf

## Sample VPN Scripts
### Open VPN
```
cd C:\Tools4ever\Scripts
taskkill /S localhost /im vpncli.exe /f /t
taskkill /S localhost /im vpnui.exe /f /t
"c:\program files (x86)\Cisco\Cisco AnyConnect Secure Mobility Client\vpncli.exe" -s < connect.txt
```
### Close VPN
```
cd C:\Tools4ever\Scripts
"c:\program files (x86)\Cisco\Cisco AnyConnect Secure Mobility Client\vpncli.exe" disconnect
```
### VPN Client Config
```
connect vpn-1.iscorp.com
idofgroup
thisismusername
thisismypassword
y
quit
```
