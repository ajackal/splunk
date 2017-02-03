# currently must be 'runas' administrator for proper install
# echos can be removed for silent install
# i left them for troubleshooting

# directory to check for splunk installation
$loc = 'C:\Program Files\*'

# URI to download the install file
$insturi = 'http://192.168.1.180/splunkuniversalforwarder.msi'

# directory for file to be downloaded to:
# currently set to download in the path that the script is in:
# this is advised or you need to change more settings
$path = Convert-Path .
$outputdir = $path + '\splunkuniversalforwarder.msi'

# file name of .msi installation file
$instfile = 'splunkuniversalforwarder.msi'

# hostname or ip : port of indexer
$ind = '192.168.1.180:9997'

# hostname or ip : port of deploymentServer
$depserv = '192.168.1.180:8089'

# path to inputs.conf
$lif = 'C:\Program Files\SplunkUniversalForwarder\etc\system\local\inputs.conf'

# variables to add to inputs.conf for powershell log forwarding
$fdmo = "`r`n[WinEventLog://Microsoft-Windows-PowerShell-DesiredStateConfiguration-FileDownloadManager/Operational]`r`ndisabled = 0`r`n"
$mwpo = "`r`n[WinEventLog://Microsoft-Windows-PowerShell/Operational]`r`ndisabled = 0`r`n"

# variable to restart splunkd
$rtp = 'C:\Program` Files\SplunkUniversalForwarder\bin\splunk.exe restart'

# variable used to delete script after its run and installed correctly
$self = $path + '\splunk-script-v1.1.ps1'


echo "[*] checking for previous installations of splunk>..."

# checks to see if a splunk folder already exists in Program Files
# will skip installation if it finds a splunk folder

if (Test-Path -Path $loc -Include "*splunk*")
{
    echo "[!] a copy of splunk> is already installed!"
    exit 0
}else{
    echo "[*] downloading splunk> universal forwarder..."

    # downloads splunk install file
    # this method significantly faster than Invoke-WebRequest
    (New-Object System.Net.WebClient).DownloadFile($insturi, $outputdir) 

    echo "[*] installing splunk> universal fowarder..."
    
    # uses msi to install splunk forwarder, file names need to match and be co-located
    # /quiet suppresses gui, otherwise the script will fail
    # additional switches would be needed for an enterprise installation
    # testing on whether local user can collect log files (i believe no)
    # might need to be installed as a domain user or local admin?
    # see: <http://docs.splunk.com/Documentation/Forwarder/6.5.1/Forwarder/InstallaWindowsuniversalforwarderfromthecommandline>
    # for supported switches and installation instructions
    Start-Process -FilePath msiexec.exe -ArgumentList "/i $instfile DEPLOYMENT_SERVER=$depserv RECEIVING_INDEXER=$ind AGREETOLICENSE=Yes /quiet" -Wait
    
    # added to be sure the splunk app has time to boot properly before checking in the function below
    # the -Wait option above, might have fixed problem with script quitting before splunk had time to boot
    # try elminating the sleep, or reducing the time to speed up installation
    Sleep 3
}


# checks to see if splunkd is running which indicates good install
# then adds the necessary lines to input.conf to retreive powershell logs

$splunk = Get-Process -Name "splunkd" -ErrorAction SilentlyContinue

if ($splunk -ne $null)  # checks for running splunkd process
{
    echo "[*] splunk has successfully started."
    echo "[*] editing config files..."

    # writes lines to inputs.conf
    # had to add encoding switch to fix issues when installing on windows 8.1
    Out-File -Encoding utf8 -Append -FilePath $lif -InputObject $mwpo, $fdmo
    
    echo "[*] restarting splunk to apply changes..."
    
    Invoke-Expression $rtp  # restarts splunkd so changes take effect
    
    if ($splunk -ne $null)  # confirms if it restarted successfully
    {
        echo "[*] splunk> successfully restarted."
        echo "[*] running clean up."
        
        Remove-Item $instfile
        
        echo "[*] clean up complete. Exiting..."
        # uncomment line below to have the script delete itself when the installation is complete
        # Remove-Item $self
        exit 0
    }else{
        echo "[!] splunk> currently not running, try manually restarting...exiting."
        exit 0
    }
}else{
    echo '[!] splunk process not running!'
    echo '[!] check to make sure installation was successful.'
    exit 0
}

# installation/script execution is fast
# this is gives you a chance to review terminal
# for feedback
pause
