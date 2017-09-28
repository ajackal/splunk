# Objects holding information to send to Splunk:
$objects_to_send = @()

function postResultsToSplunk ($input_content){
    $token = "91C89412-C607-48FE-B0CC-7042A5548A67"
    $headers = @{"Authorization" = "Splunk $token"}
    $body = @{
        "host" = $env:COMPUTERNAME;
        "source" = "IR-triage-script";
        "sourcetype" = "IR-RESTapi";
        "index" = "main";
        "event" = $input_content
    }

    $json_body = ConvertTo-Json -InputObject $body -Compress
    $json_body = $json_body -replace '(^\s+|\s+$)','' -replace '\s+',''
    $json_body = $json_body -replace '\t',''

    Invoke-RestMethod -Method POST -Uri "http://10.55.12.78:8088/services/collector/event" -Headers $headers -ContentType "application/json" -Body $json_body
    
}

# Dumps Local User Accounts, whether they are enabled and a description (if given):
# Some reverse compatibility issues, if so try Get-WmiObject.
$local_users = Get-LocalUser
$objects_to_send += $local_users
# Selects all object properties and for each object, converts them to JSON format and sends the results to Splunk:
# $local_users | Select-Object * | ForEach-Object{$_ = Select-Object * | ConvertTo-Json -InputObject $_ -Compress; postResultsToSplunk($_)}

# Grabs all network connection profiles information
$network_profile = Get-NetConnectionProfile
$objects_to_send += $network_profile
# $network_profile | Select-Object * | ForEach-Object{$_ = ConvertTo-Json -InputObject $_ -Compress; postResultsToSplunk($_)}

# Dumps current DNS cache; very volitale. 
$dns_cache = Get-DnsClientCache
$objects_to_send += $dns_cache


# Gets DNS Server Address for each interface.
$dns_server_address = Get-DnsClientServerAddress
$objects_to_send += $dns_server_address

# -IncludeUserName option requires Elevated Privileges
$process_list = Get-Process -IncludeUserName
$objects_to_send += $process_list

# Grabs installed software.
$registry_software = Get-ChildItem "HKLM:\Software"
$objects_to_send += $registry_software

# Grabs System information from the Registry
$registry_system = Get-ChildItem "HKLM:\System"
$objects_to_send += $registry_system

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

$tasks = @()

$schedule = New-Object -ComObject "Schedule.Service"
$schedule.Connect()

$tasks += getTasks("\")
$objects_to_send += $tasks

# Write PowerShell log metadata:
$getScriptBlockLog = Get-WinEvent -FilterHashTable @{ 
    LogName = "Microsoft-Windows-PowerShell/Operational"; 
    ID = 4103, 4104
}
# echo $getScriptBlockLog
# $getScriptBlockLog | Get-Member writes all the Properties of the the object.
# Prints the detailed Script Block Log message of each event.
$getScriptBlockLog.Message

# Write New Process Creation log metadata:
$newProcessCreation = Get-WinEvent -FilterHashTable @{ 
    LogName = "Security"; 
    ID = 4688
}
# echo $newProcessCreation
# $newProcessCreation | Get-Member writes all the Properties of the the object.
# Prints the detailed message for each event.
$newProcessCreation.Message

# Grabs Network Statistics for all connections. Requires Elevated Privileges.
$network_connections = netstat.exe -ano | Select-String -Pattern "established", "listening"
$objects_to_send += $network_connections
# echo $network_connections

# OR
# Not sure if I can identify the owning process with the PowerShell Module.
# Doesn't appear that I can get the Owning Process from this module.
# Get-NetTCPConnection

$objects_to_send | ForEach-Object{
    $_ | Select-Object * | ConvertTo-Json -Compress; postResultsToSplunk($_)
}