# uefi-checkscript

The uefi-checkscript.ps1 verifies that the operating system was booted from UEFI. It will display a notification if the system was booted from BIOS. This can be used in an SCCM or MDT task sequence to make sure the PC is running UEFI before the operating system is deployed.

The script can also be used to check for the presence of Secure Boot and notify the user if it is currently disabled.

More information can be found in the [wiki](https://github.com/diablolot53/uefi-checkscript/wiki).

### Parameters
**-SecureBoot**

Runs the Secure Boot check. By default only the UEFI check is performed.

**-Debug**

Displays the debug window with the status of both checks. This is not recommend for use in a task sequence, but can be helpful for diagnostic tasks from the desktop.

### WinPE Requirements
The following modules are required for WinPE
* WinPE-WMI
* WinPE-NetFX
* WinPE-Scripting
* WinPE-PowerShell
* WinPE-HTA
* WinPE-SecureBootCmdlets - Required for Secure Boot

#### [TechNet - WinPE: Add packages](https://docs.microsoft.com/en-us/windows-hardware/manufacture/desktop/winpe-add-packages--optional-components-reference)
