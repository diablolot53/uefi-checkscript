#uefi-checkscript

#This script can be used in an SCCM task sequence to see if WinPE was booted in UEFI or BIOS mode
#------------------------------------------------------------------------------------------------------------

#Parameters
Param (
	[switch]$Debug = $false,        #Enables debug mode to test the script outside of an SCCM task sequence | Default: off
	[switch]$SecureBoot = $false    #Checks the status of SecureBoot in additon to UEFI | Default: off
)


#Functions
Function Get-BiosType {
	#Function is from the GetFirmwareType.ps1 script - https://gallery.technet.microsoft.com/scriptcenter/Determine-UEFI-or-Legacy-7dc79488
<#
.Synopsis
   Determines underlying firmware (BIOS) type and returns an integer indicating UEFI, Legacy BIOS or Unknown.
   Supported on Windows 8/Server 2012 or later
.DESCRIPTION
   This function uses a complied Win32 API call to determine the underlying system firmware type.
.EXAMPLE
   If (Get-BiosType -eq 1) { # System is running UEFI firmware... }
.EXAMPLE
    Switch (Get-BiosType) {
        1       {"Legacy BIOS"}
        2       {"UEFI"}
        Default {"Unknown"}
    }
.OUTPUTS
   Integer indicating firmware type (1 = Legacy BIOS, 2 = UEFI, Other = Unknown)
.FUNCTIONALITY
   Determines underlying system firmware type
#>

[OutputType([UInt32])]
Param()

Add-Type -Language CSharp -TypeDefinition @'

    using System;
    using System.Runtime.InteropServices;

    public class FirmwareType
    {
        [DllImport("kernel32.dll")]
        static extern bool GetFirmwareType(ref uint FirmwareType);

        public static uint GetFirmwareType()
        {
            uint firmwaretype = 0;
            if (GetFirmwareType(ref firmwaretype))
                return firmwaretype;
            else
                return 0;   // API call failed, just return 'unknown'
        }
    }
'@


    [FirmwareType]::GetFirmwareType()
}

Function DisplayWindow {
	<#
	.Synopsis
		Displays an informative or interactive window for user input or to display the results of task
	.DESCRIPTION
		
	.EXAMPLE

	.OUTPUTS
		
	.FUNCTIONALITY
		
	#>
}


#Query the system for the BIOS status
$UEFIResults = Get-BiosType

#Check for SecureBoot if UEFI is enabled and the SecureBoot parameter is defined
If (($UEFIResults -eq 2) -and ($SecureBoot = $true)){
	$SecureBootResult = Confirm-SecureBootUEFI
}

#Display Results if the Debug parameter is set
