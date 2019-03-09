param (
    [string]$user = "mike-w-kelly", #default user
    [int]$interval = 10,
    [switch]$repeat
 )
 
$lastQueriedDateTime = Get-Date -UFormat '+%Y-%m-%dT%H:%M:%S.00Z'

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

function Get-Gists([String] $userName) {
    Write-Host "Getting gists for $($userName)"
    
    $uri = "https://api.github.com/users/{0}/gists" -f $userName
    $gists = Invoke-RestMethod -Method Get -Uri $uri

    if ($gists.Length -eq 0) {
        Write-Host "No gists found for user $($user)"
    }

    $lastQueriedDateTime = Get-Date -UFormat '+%Y-%m-%dT%H:%M:%S.00Z'

    return $gists   
}

$result = Get-Gists -userName $user

if ($result.Length -gt 0) {    
    $result | ForEach-Object { $_ } | Format-Table # default, output to powershell window
}

# Async call to check the Gist api for new gists
$timer = New-Object Timers.Timer
$timer.Interval = $interval * 1000 # seconds to ms

if ($repeat) {
    $timer.AutoReset = $true # runs everytime timer expires, default every 10 seconds
} else {
    $timer.AutoReset = $false # runs once, default
}
 
$timer.Enabled = $true

$data = @{}
$data.UserName = $user
$data.Since = $lastQueriedDateTime
$data.Repeat = $repeat

# Event will be added to event queue for this session
Register-ObjectEvent -InputObject $timer -EventName "Elapsed" -SourceIdentifier "check for new gists" `
    -Action { 
        Write-Host "Checking for new gists by $($Event.MessageData.UserName) since $($Event.MessageData.Since)"
        $uri = "https://api.github.com/users/{0}/gists" -f $Event.MessageData.UserName
        Write-Host $uri

        $body = @{
            since = $Event.MessageData.Since
        }

        Write-Host $body

        $gists = Invoke-RestMethod -Method Get -Uri $uri -Body $body

        if ($gists.Length -gt 0) {
            Write-Host "Found $($gists.Length) new gists for $($Event.MessageData.UserName)"
            $gists | ForEach-Object { $_ } | Format-Table | Out-Host    
        } else {
            Write-Host "No new gists found for $($Event.MessageData.UserName)"
        } 

        $lastQueriedDateTime = Get-Date -UFormat '+%Y-%m-%dT%H:%M:%S.00Z'

        Write-Host "Check finished"   
        
        if ($Event.MessageData.Repeat -eq $false) {
            Write-Host "Repeat param not provided, unregister event"
            Unregister-Event -SourceIdentifier "check for new gists"
        }
    } `
    -MessageData $data

Get-EventSubscriber






