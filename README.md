# Splunk>

## Splunk HTTP Event Collector
`Splunk_HTTP_Collector.ps1`

A PowerShell script that uses a REST API to POST data to a Splunk server with the HTTP Event Collector service enabled. Formatting the JSON properly is critical for Splunk to accept the POST and parse the JSON properly.

## Splunk Install Script
`splunk-script.ps1`

A PowerShell script to download a Splunk Universal Forwarder from a remote server, install, configure and then remove the installation pacakge from the system. _TODO:_ add error handling and messaging to a Splunk HTTP Event Collector.

## Splunk Inputs Configuration
`inputs.conf`

The Splunk `inputs.conf` file modified to collect PowerShell/Operational and Sysmon/Operational logs. Needs to be modified from the `$SPLUNK_HOME/etc/system/local` directory.
