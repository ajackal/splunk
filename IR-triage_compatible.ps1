# Objects holding information to send to Splunk:
$objects_to_send = @()

# Function builds the objects necessary to send results to Splunk's HTTP Event Collector.
function postResultsToSplunk ($input_content){
    $token = "91C89412-C607-48FE-B0CC-7042A5548A67"
    $headers = @{"Authorization" = "Splunk $token"}
    $body = @{
        "host" = $env:COMPUTERNAME;
        "source" = "IR-triage-script";
        "sourcetype" = "IR-RESTapi";
        "index" = "main";
        "event" = @{
                "case_number" = "EJDIE34500";
                "info" = $input_content;
            } 
    }

    $json_body = ConvertTo-Json -InputObject $body -Compress
    # $json_body = $json_body -replace '(^\s+|\s+$)','' -replace '\s+',''
    # $json_body = $json_body -replace '\t',''

    Invoke-RestMethod -Method POST -Uri "http://10.55.12.78:8088/services/collector/event" -Headers $headers -ContentType "application/json" -Body $json_body
    
}

# Checks PowerShell version, if 5.0 runs the new cmdlets, otherwise runs legacy (WMI) cmdlets.
if ($PSVersionTable.PSVersion.Major -eq 5){
    # Dumps Local User Accounts, whether they are enabled and a description (if given):
    # Some reverse compatibility issues, if so try Get-WmiObject.
    try{
        $local_users = Get-LocalUser    
    }catch{
        $local_users = "Error running Get-LocalUser cmdlet."
    } 
    $objects_to_send += $local_users
    
    # Grabs all network connection profiles information
    try{
        $network_profile = Get-NetConnectionProfile
    }catch{
        $network_profile = "Error running Get-NetConnectionProfile cmdlet."
    }    
    $objects_to_send += $network_profile
    
    # Dumps current DNS cache; very volitale. 
    try{
        $dns_cache = Get-DnsClientCache
    }catch{
        $dns_cache = "Error running Get-DnsClientCache cmdlet."
    }
    $objects_to_send += $dns_cache
    
    # Gets DNS Server Address for each interface.
    try{
        $dns_server_address = Get-DnsClientServerAddress
    }catch{
        $dns_server_address = "Error running Get-DnsClientServerAddress cmdlet."
    }
    $objects_to_send += $dns_server_address
} else {
    # Gets Local Accounts of the computer:
    try{
        $local_users_wmi = Get-WmiObject -class Win32_UserAccount -Filter "LocalAccount='True'" | Select-Object PsComputername, Name, Status, Disabled, AccountType, Lockout, PasswordRequired, PasswordChangeable, SID
    }catch{
        $local_users_wmi = "Errorr running legacy Local User (WMI) cmdlet."
    }
    $objects_to_send += $local_users_wmi

    # Gets Computer Hardware information & Last Logged In User information:
    try{
        $computer_system_info = Write-Output "`nComputerName`t`t: $env:computername"; Get-WmiObject -computer $env:computername -class win32_computersystem | Select-Object Username, Domain, Manufacturer, Model, SystemType, PrimaryOwnerName, TotalPhysicalMemory
    }catch{
        $computer_system_info = "Error running legacy Computer System Information (WMI) cmdlet."
    }
    $objects_to_send += $computer_system_info

    # Gets current ip config settings including DNS and Default Gateway settings & converts to JSON:
    try{
        $ip_dns_config = Get-WmiObject Win32_NetworkAdapterConfiguration | Where-Object {$_.ipaddress -notlike $null} | Select-Object PSComputerName, IPAddress, IPSubnet, DefaultIPGateway, Description, DHCPEnabled, DHCPServer, DNSDomain, DNSDomainSuffixSearchOrder, DNSServerSearchOrder, WINSPrimaryServer, WINSSecondaryServer
        $ip_dns_config = $ip_dns_config | Select-Object * |  ForEach-Object {$_.IPaddress = $_.IPAddress.Replace("\{",""); $_.DefaultIPGateway = $_.DefaultIPGateway.Replace("\{",""); $_.IPSubnet = $_.IPSubnet.Replace("\{",""); $_}
    }catch{
        $ip_dns_config = "Error running legacy IP/DNS Config (WMI) cmdlet."
    }
    $objects_to_send += $ip_dns_config
}

# -IncludeUserName option requires Elevated Privileges
try{
    $process_list = Get-Process -IncludeUserName
}catch{
    $process_list = "Error running Get-Process cmdlet with -IncludeUserName option. Were you running as Admin?"
}
$objects_to_send += $process_list

# Gets the current list of services, both running and stopped:
try{
    $services = Get-Service
}catch{
    $services = "Error running Get-Service cmdlet."
}
$objects_to_send += $services

# Grabs installed software.
try{
    $registry_software = Get-ChildItem "HKLM:\Software"
}catch{
    $registry_software = "Error running Get-ChildItem on HKLM:\Software registry key."
}
$objects_to_send += $registry_software

# Grabs System information from the Registry
try{
    $registry_system = Get-ChildItem "HKLM:\System"
}catch{
    $registry_system = "Error running Get-ChildItem on HKLM:\System registry key."
}
$objects_to_send += $registry_system

# Function & required COM object to retrieve all scheudled tasks:
$tasks = @()
function getTasks($path) {
    $out = @()

    $schedule.GetFolder($path).GetTasks(0) | ForEach-Object {
        $xml = [xml]$_.xml
        $out += New-Object psobject -Property @{
            "Name" = $_.Name
            "Path" = $_.Path
            "LastRunTime" = $_.LastRunTime
            "NextRunTime" = $_.NextRunTime
            "Actions" = ($xml.Task.Actions.Exec | ForEach-Object {"$($_.Command) $($_.Arguments)"})
        }
    }

    $schedule.GetFolder($path).GetFolders(0) | ForEach-Object {
        $out += getTasks($_.Path)
    }

    $out
}

try{
    $schedule = New-Object -ComObject "Schedule.Service"
    $schedule.Connect()

    $tasks += getTasks("\")
}catch{
    $tasks = "Error retrieving Scheduled Tasks list."
}
$objects_to_send += $tasks

# Get PowerShell Transcriptions from C:\temp\PowerShellLogs
$default_transcription_path = 'C:\temp\PowerShellLogs'
$transcription_file_path = Get-ItemProperty "HKLM:\software\Policies\Microsoft\Windows\PowerShell\Transcription" | Select-Object -ExpandProperty OutputDirectory
try{
    if (Test-Path -Path $default_transcription_path){
        $ps_transcription_logs = Get-ChildItem C:\temp\PowerShellLogs\ | ForEach-Object{Get-Content C:\temp\PowerShellLogs\$_}
    }elseif($transcription_file_path -ne $default_transcription_path){
        $ps_transcription_logs = Get-ChildItem $transcription_file_path | ForEach-Object{Get-Content $transcription_file_path\$_}
    }else{
        $ps_transcription_logs = "[!] Error: PowerShell Log directory doesn't exist."
    }
}catch{
    $ps_transcription_logs = "Error retrieving PowerShell Transcription logs. Is Transcription enabled on this machine?"
}
$objects_to_send += $ps_transcription_logs

# Write PowerShell log metadata:
try{
    $getScriptBlockLog = Get-WinEvent -FilterHashTable @{ 
        LogName = "Microsoft-Windows-PowerShell/Operational"; 
        ID = 4103, 4104
    }
}catch{
    $getScriptBlockLog = "Error retrieving Deep Script Block logs."
}
$objects_to_send += $getScriptBlockLog
# echo $getScriptBlockLog
# $getScriptBlockLog | Get-Member writes all the Properties of the the object.
# Prints the detailed Script Block Log message of each event.
# $getScriptBlockLog.Message

# Write New Process Creation log metadata:
try{
    $newProcessCreation = Get-WinEvent -FilterHashTable @{ 
        LogName = "Security"; 
        ID = 4688
    }
}catch{
    $newProcessCreation = "Error retrieving New Process Creation (ID=4688) from Security logs."
}
$objects_to_send += $newProcessCreation
# $newProcessCreation | Get-Member writes all the Properties of the the object.
# Prints the detailed message for each event.
# $newProcessCreation.Message

# Grabs Network Statistics for all connections. Requires Elevated Privileges.
try{
    $network_connections = netstat.exe -ano | Select-String -Pattern "established", "listening"
}catch{
    $network_connections = "Error retrieving network connection information."
}
$objects_to_send += $network_connections


# OR
# Not sure if I can identify the owning process with the PowerShell Module.
# Doesn't appear that I can get the Owning Process from this module.
# Get-NetTCPConnection

$objects_to_send | ForEach-Object{
    $_ | Select-Object * | ConvertTo-Json -Compress; postResultsToSplunk($_)
}