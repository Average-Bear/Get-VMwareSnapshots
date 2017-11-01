<#
.SYNOPSIS
    List snapshots on all VMWARE ESX/ESXi servers as well as VM's managed by Virtual Center.

.DESCRIPTION
    List snapshots on all VMWARE ESX/ESXi servers as well as VM's managed by Virtual Center.

.PARAMETER Hostname
    ESXi host or vCenter DNS name/IP Address.

.PARAMETER Username
    Set username for ESXi/vCenter login.

.PARAMETER To
    Set a recipient mailbox to send the report; [To:] address.

.PARAMETER From
    Set an outbound mail address; [From:] address

.PARAMETER File
    Set save location for data export to CSV.

.SWITCH Credential
   Prompt for single credential, uses for all host/vCenter login attempts.

.EXAMPLE
    .\Get-VMwareSnaphots.ps1

.NOTES
    Author: Chris Uys
    Date: Unknown

    Editor: Jeremy DeWitt (JBear)
    Date: 10/22/2017
#>
param (
    
    [Parameter(ValueFromPipeline=$true,HelpMessage="Enter Hostname/IP for ESXi Hosts or vCenter")]
    [ValidateNotNullOrEmpty()] 
    [String[]]$Hostname = @(
        
        "Host1",
        "Host2"
    ),
   
    [Parameter(ValueFromPipeline=$true,HelpMessage="Username with minimum Read-Only access to specified Host(s)/vCenter(s)")]
    [ValidateNotNullOrEmpty()] 
    [String]$Username = "root",

    [Parameter(ValueFromPipeline=$true,HelpMessage="Set the [TO:] address to a group mailbox; (i.e. USCMD.somegroupmailbox.@acme.com)")]
    [ValidateNotNullOrEmpty()] 
    [String]$To = "whatever@acme.something.com",

    [Parameter(ValueFromPipeline=$true,HelpMessage="Set [From:] address ; (i.e. System.Automation@hostname.com)")]
    [ValidateNotNullOrEmpty()] 
    [String]$From = "System.Automation@hostname.com",

    [Parameter(ValueFromPipeline=$true,HelpMessage="Set SMTP host")]
    [ValidateNotNullOrEmpty()] 
    [String]$SMTPHost = "SMTP.Hostname.Local" ,

    [Parameter(ValueFromPipeline=$true,HelpMessage="CSV output file location [will overwrite]")]
    [ValidateNotNullOrEmpty()] 
    [String]$File = "\\NetShare\Foo\Bar\VMwareSnapshots.csv",

    [Switch]$Credential
)

if($Credential) {

    $Creds = (Get-Credential -Credential $Username)
}

function Get-SnapInfo {
    
    #Get snapshots from all servers
    foreach ($ESX in $HostName) {
		
	#If $Creds exists, connect with $Creds
	if($Creds) {
            
            Write-Host -ForegroundColor Yellow "Attempting connection to $ESX..."

            Try {

                Connect-VIServer $ESX -Credential $Creds
                Write-Host -ForegroundColor Green "Connection Succesful!`n"
            }

            Catch {
            
                Write-Host -ForegroundColor Red "Connection Failed! Check specified credentials.`n"
            }
        }
		
        #Connect with current user session
	    else {

            Write-Host -ForegroundColor Yellow "Attempting connection to $ESX..."

            Try {

                Connect-VIServer $ESX
                Write-Host -ForegroundColor Green "Connection Succesful!`n"
            }

            Catch {
            
                Write-Host -ForegroundColor Red "Connection Failed! Current session credentials can't login to $ESX`n"
            }
        }	
    }
		
    $Snapshots = Get-VM | Get-Snapshot | Select VM, Name, Created, Description

    foreach($Snap in $Snapshots) {

        [PSCustomObject] @{

            VMName = $Snap.VM.Name
	    SnapshotName = $Snap.Name
	    Created = $Snap.Created
	    Description = $Snap.Description
        }
    }
}

$SnapInfo = Get-SnapInfo | Select VMName, SnapshotName, Created, Description | Sort VMName

Write-Host -ForegroundColor DarkMagenta "[Notice] Exporting snapshot data to $File`n" 
$SnapInfo | Export-Csv -NoTypeInformation -Path $File -Force

#Send email	
if(!($SnapInfo)) {

    $SmtpClient = New-Object System.Net.Mail.SmtpClient
     
    #SMTP server
    $SMTPClient.Host = $SMTPHost 
    $MailMessage = New-Object System.Net.Mail.MailMessage

    #Outbound email address
    $MailMessage.From = $From 
  
    #Receiving email group or individual
    $MailMessage.To.Add("$To")
    $MailMessage.IsBodyHtml = 1
    $MailMessage.Subject = "VMware Snapshots"
    $MailMessage.Body = $SnapInfo
    $SMTPClient.Send($MailMessage)
}
