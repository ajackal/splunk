# How to POST data to an HTTP Event Collector in Splunk:
# Define $headers which includes the authenication $token generated in Splunk:
$token = "91C89412-C607-48FE-B0CC-7042A5548A67"
$headers = @{"Authorization" = "Splunk $token"}

# Define the data that you want to send, and then convert it to JSON format:
$body = @{
    "host" = $host;
    "source" = "ir-script";
    "sourcetype" = "IR-REST";
    "index" = "main";
    "event" = @{
        "users" = "bob, john, allie"; 
        "passwords" = "steelers, lassie, girlsrule"
    }
}
# Convert to JSON, "-InputObject" may not be required; seems to work well without it.
# Depth and Compress help with proper JSON parsing in Splunk along with removing brackets '[]' and whitespace
$json_body = ConvertTo-Json -InputObject $body -Depth 1 -Compress
$json_body = $json_body -replace '\s',''
# $json_body = $json_body -replace '\[',''
# $json_body = $json_body -replace '\]','' # removes brackets

# Final PowerShell command:
Invoke-RestMethod -Method POST -Uri "http://yourSplunksever.local:8088/services/collector/event" -Headers $headers -ContentType "application/json" -Body $json_body

# For testing the script:
$body = @{"host" = "10.55.12.38"; "source" = "ir-script"; "sourcetype" = "IR-REST"; "index" = "main"; "event" = @{"users" = "bob, john, allie"; "passwords" = "steelers, lassie, girlsrule"}}

$body = @{
    "host" = $host;
    "source" = "ir-script";
    "sourcetype" = "IR-REST";
    "index" = "main";
    "event" = $content
}