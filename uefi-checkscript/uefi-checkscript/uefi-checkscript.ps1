#uefi-checkscript

#This script can be used in an SCCM task sequence to see if WinPE was booted in UEFI or BIOS mode
#------------------------------------------------------------------------------------------------------------

#Parameters
Param (
	[switch]$Debug = $false,        #Enables debug mode to test the script outside of an SCCM task sequence | Default: off
	[switch]$SecureBoot = $false    #Checks the status of SecureBoot in addition to UEFI | Default: off
)

#-------------------------------------------------------------

#Functions
Function Get-BiosType {
	#Function is derived from the code provided in the GetFirmwareType.ps1 script by Chris J Warwick - https://gallery.technet.microsoft.com/scriptcenter/Determine-UEFI-or-Legacy-7dc79488
	[OutputType([UInt32])]
	Param()

	If ((Get-CimInstance win32_OperatingSystem).Caption -like "*Windows 7*"){
		#If Win7
		<#
		.Synopsis
		   Determines underlying firmware (BIOS) type and returns True for UEFI or False for legacy BIOS.
		.DESCRIPTION
		   This function uses a complied Win32 API call to determine the underlying system firmware type.
		.EXAMPLE
		   If (IsUEFI) { # System is running UEFI firmware... }
		.OUTPUTS
		   [Bool] True = UEFI Firmware; False = Legacy BIOS
		.FUNCTIONALITY
		   Determines underlying system firmware type
		#>

	Add-Type -Language CSharp -TypeDefinition @'

    using System;
    using System.Runtime.InteropServices;

    public class CheckUEFI
    {
        [DllImport("kernel32.dll", SetLastError=true)]
        static extern UInt32 
        GetFirmwareEnvironmentVariableA(string lpName, string lpGuid, IntPtr pBuffer, UInt32 nSize);

        const int ERROR_INVALID_FUNCTION = 1; 

        public static uint IsUEFI()
        {
            // Try to call the GetFirmwareEnvironmentVariable API.  This is invalid on legacy BIOS.

            GetFirmwareEnvironmentVariableA("","{00000000-0000-0000-0000-000000000000}",IntPtr.Zero,0);

            if (Marshal.GetLastWin32Error() == ERROR_INVALID_FUNCTION)

                return 1;     // API not supported; this is a legacy BIOS

            else

                return 2;      // API error (expected) but call is supported.  This is UEFI.
        }
    }
'@


		[CheckUEFI]::IsUEFI()
	}
	Else{
		#If Win8 or later
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
}

Function DisplayWindow {
	<#
	.Synopsis
		Displays an informative or interactive window using the Windows Presentation Foundation
	.DESCRIPTION
		This function will display a GUI window based on the provided XAML
	.EXAMPLE
	
	.OUTPUTS
		
	.FUNCTIONALITY
		Display a WPF window from Powershell
	.NOTES
		This function is based on the examples that can be found at 
			https://foxdeploy.com/2015/04/10/part-i-creating-powershell-guis-in-minutes-using-visual-studio-a-new-hope/
			and
			https://foxdeploy.com/2015/04/16/part-ii-deploying-powershell-guis-in-minutes-using-visual-studio/ 
	#>

	#Parameters
	Param(
		[parameter(Mandatory=$True)]
		[String]$inputXML,
        [String]$OkButtonName,
		$labelText
	)

    $inputXML = $inputXML -replace 'mc:Ignorable="d"','' -replace "x:N",'N'  -replace '^<Win.*', '<Window'

	[void][System.Reflection.Assembly]::LoadWithPartialName('presentationframework')
	[xml]$XAML = $inputXML
	#Read XAML
 
    	$reader=(New-Object System.Xml.XmlNodeReader $xaml)
  	  try{$Form=[Windows.Markup.XamlReader]::Load( $reader )}
	catch{Write-Host "Unable to load Windows.Markup.XamlReader. Double-check syntax and ensure .net is installed."}
 
	#===========================================================================
	# Load XAML Objects In PowerShell
	#===========================================================================

	$xaml.SelectNodes("//*[@Name]") | %{Set-Variable -Name "WPF$($_.Name)" -Value $Form.FindName($_.Name)}

	Function Get-FormVariables{
	if ($global:ReadmeDisplay -ne $true){Write-host "If you need to reference this display again, run Get-FormVariables" -ForegroundColor Yellow;$global:ReadmeDisplay=$true}
	write-host "Found the following interactable elements from our form" -ForegroundColor Cyan
	get-variable WPF*
	}
 	
	#Displays the editable variabled in the WPF form
	#Get-FormVariables
 
	#===========================================================================
	# Actually make the objects work
	#===========================================================================

	#Set the Ok button to close the form when clicked
	If ($OkButtonName -ne $null){
		(Get-Variable -Name "WPF$OkButtonName" -ValueOnly).Add_Click({$form.close()})
	}
 	
	#Modify the return labels to display values from the script
	If ($labelText -ne $null){
		ForEach ($l in $labelText){
			(Get-Variable -Name ("WPF" + $l.LabelName) -ValueOnly).Content = $l.Value
		}
	}

	#===========================================================================
	# Shows the form
	#===========================================================================
	#write-host "To show the form, run the following" -ForegroundColor Cyan
	$Form.ShowDialog() | out-null
}

#-------------------------------------------------------------

#Query the system for the BIOS status
$UEFIResults = Switch (Get-BiosType) {
        1       {"Legacy BIOS"}
        2       {"UEFI"}
        Default {"Unknown"}
    }

#Check for SecureBoot if UEFI is enabled and the SecureBoot parameter is defined
If (($UEFIResults -eq "UEFI") -and ($SecureBoot -eq $true)){
	Try{$SecureBootResult = Confirm-SecureBootUEFI -ErrorAction SilentlyContinue}
		<#
		Confirm-SecureBootUEFI
		If the computer supports Secure Boot and Secure Boot is enabled, then this cmdlet returns True. 
		If the computer supports Secure Boot and Secure Boot is disabled, then this cmdlet returns False. 
		#>
	Catch{$SecureBootResult = "No"}
		#If the computer does not support Secure Boot or is a BIOS (non-UEFI) computer, then this cmdlet returns an error displaying the following: Cmdlet not supported on this platform.
}
ElseIf (($UEFIResults -eq "Legacy BIOS") -and ($SecureBoot -eq $true)){
	$SecureBootResult = "Not Supported"
}
Else{
	$SecureBootResult = "Not Checked"
}

#Display Results if the Debug parameter is set
If ($Debug -eq $True){
	#XML copied from the MainWindow.xaml file
	$window = @"
<Window x:Class="WpfApp1.DebugWindow"
        xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        xmlns:d="http://schemas.microsoft.com/expression/blend/2008"
        xmlns:mc="http://schemas.openxmlformats.org/markup-compatibility/2006"
        xmlns:local="clr-namespace:WpfApp1"
        mc:Ignorable="d"
        Title="DebugWindow" Height="191.597" Width="352.941" WindowStartupLocation="CenterScreen">
    <Grid>
        <Grid.ColumnDefinitions>
            <ColumnDefinition Width="38*"/>
            <ColumnDefinition Width="77*"/>
        </Grid.ColumnDefinitions>
        <Button x:Name="OkButton" Content="Ok" HorizontalAlignment="Left" Margin="16.353,122,0,0" VerticalAlignment="Top" Width="75" IsDefault="True" Grid.Column="1"/>
        <Label Content="Boot Mode:" HorizontalAlignment="Left" Margin="38,26,0,0" VerticalAlignment="Top"/>
        <Label x:Name="BootModeStatus" Content="UEFI|BIOS" HorizontalAlignment="Left" Margin="69.353,26,0,0" VerticalAlignment="Top" Grid.Column="1"/>
        <Label Content="SecureBoot Enabled:" HorizontalAlignment="Left" Margin="38,57,0,0" VerticalAlignment="Top" Grid.ColumnSpan="2"/>
        <Label x:Name="SecBootStatus" Content="Not Checked" HorizontalAlignment="Left" Margin="69.353,57,0,0" VerticalAlignment="Top" Grid.Column="1"/>

    </Grid>
</Window>
"@

	#Create tge object to send the BIOS & SecureBoot results to the debug window
	$labels = @()

	#Add the UEFI results
	$labelsTemp = New-Object -TypeName PSObject
	$labelsTemp | Add-Member -MemberType NoteProperty -Name LabelName -Value "BootModeStatus"
	$labelsTemp | Add-Member -MemberType NoteProperty -Name Value -Value $UEFIResults
	$labels += $labelsTemp
	Clear-Variable labelsTemp
	
	#Add the SecureBoot results only if the parameter is defined
	#By default the window will display "Not Checked"
	If ($SecureBoot -eq $true){
		$labelsTemp = New-Object -TypeName PSObject
		$labelsTemp | Add-Member -MemberType NoteProperty -Name LabelName -Value "SecBootStatus"
		$labelsTemp | Add-Member -MemberType NoteProperty -Name Value -Value $SecureBootResult
		$labels += $labelsTemp
		Clear-Variable labelsTemp
	}

	

	#Display the window
	DisplayWindow -inputXML $window -OkButtonName "OkButton" -labelText $labels
}
Else{
	#Return return results of the check
	#If UEFI is not enabled, display a notification and exit the script with an error
	If ($UEFIResults -ne "UEFI"){
		#Display a notification window
		$window = @"
<Window x:Class="WpfDebugWindow.UEFINotification"
        xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        xmlns:d="http://schemas.microsoft.com/expression/blend/2008"
        xmlns:mc="http://schemas.openxmlformats.org/markup-compatibility/2006"
        xmlns:local="clr-namespace:WpfDebugWindow"
        mc:Ignorable="d"
        Title="UEFI Error" Height="187.5" Width="349.794" WindowStartupLocation="CenterScreen" ResizeMode="NoResize">
    <Grid Margin="10,10,8,8">
        <Label Content="UEFI is currently disabled&#xD;&#xA;" Margin="19,10,0,0" VerticalAlignment="Top" Height="27" Width="250" HorizontalContentAlignment="Center" HorizontalAlignment="Left"/>
        <Label Content="Please reboot the system and enable UEFI from the &#xD;&#xA;firmware interface" Margin="10,37,4,0" VerticalAlignment="Top" Height="38" FontSize="11"/>
        <Button x:Name="OkButton" Content="Ok" Margin="114,93,0,10" Width="94" HorizontalContentAlignment="Center" VerticalContentAlignment="Center" HorizontalAlignment="Left"/>

    </Grid>
</Window>
"@

		DisplayWindow -inputXML $window -OkButtonName "OkButton"

		#Exit with an error code that will cause the task sequence to fail
		Exit 1
	}

	#Display a notification if UEFI is enabled but Secureboot is turned off
	If (($SecureBoot -eq $true) -and ($SecureBootResult -eq $false)){
		#Display a notification window
		
	}

	#If UEFI is enabled and SecureBoot check passed (if checked) then exit the script w/o any error codes
	Exit
}