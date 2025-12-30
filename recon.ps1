<#
    Ultimate Recon Framework – Windows Edition
    Purpose: Authorized Security Testing / Bug Bounty / Pentesting ONLY
    Version: 1.0.0
    Date: 2025
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [string]$Domain,

    [string]$Wordlist = "wordlists\dir-medium.txt",

    [string]$NucleiSeverity = "critical,high,medium",

    [switch]$DryRun
)

# Domain validation
if ($Domain -notmatch '^[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$') {
    Write-Host "ERROR: Invalid domain format." -ForegroundColor Red
    exit 1
}

# Legal banner
Clear-Host
Write-Host "══════════════════════════════════════════════════════════════" -ForegroundColor Red
Write-Host "              AUTHORIZED SECURITY TESTING ONLY" -ForegroundColor Yellow
Write-Host " Target: $Domain" -ForegroundColor White
Write-Host " This tool must only be used on targets you own or have" -ForegroundColor Yellow
Write-Host " explicit written permission to test." -ForegroundColor Yellow
Write-Host "══════════════════════════════════════════════════════════════" -ForegroundColor Red
Read-Host "Press Enter to confirm authorization" | Out-Null

# Configuration
$Config = @{
    HttpxRate      = 120
    NucleiRate     = 30
    FFUFThreads    = 40
    KatanaDepth    = 3
    MaxTargets     = 6
    NaabuPorts     = 1000
    LogFile        = "recon.log"
}

# Setup
$OutDir = "$Domain-recon"
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
Set-Location $OutDir

# Helpers
function Log {
    param($Msg, $Lvl = "INFO")
    $t = Get-Date -Format "HH:mm:ss"
    $l = "[$t][$Lvl] $Msg"
    Write-Host $l
    $l | Out-File $Config.LogFile -Append -Encoding utf8
}

function Tool-Exists { param($n) $null -ne (Get-Command $n -ErrorAction SilentlyContinue) }

function Execute {
    param($Cmd)
    if ($DryRun) { Log "[DRY-RUN] $Cmd" "DRY"; return }
    Log "RUN → $Cmd"
    Invoke-Expression $Cmd
}

function Step-Done { param($n) Test-Path ".done_$n" }
function Mark-Done { param($n) New-Item ".done_$n" -ItemType File -Force | Out-Null }

function Require-File {
    param($f, $s)
    if (-not (Test-Path $f)) { Log "Missing $f → run step $s first" "ERROR"; return $false }
    return $true
}

# Tool check
$Tools = @("subfinder","amass","httpx","gau","waybackurls","katana","ffuf","nuclei","dalfox","naabu","tlsx","puredns","dnsx")
foreach ($t in $Tools) {
    if (-not (Tool-Exists $t)) { Log "$t not found in PATH" "WARN" }
}

# Steps
function Step-Subdomains {
    if (Step-Done "subs") { Log "Subdomains already completed"; return }
    Execute "subfinder -d $Domain -all -silent -o subs_subfinder.txt"
    Execute "amass enum -passive -d $Domain -o subs_amass.txt"
    Get-Content subs_*.txt -ErrorAction SilentlyContinue | Sort-Object -Unique | Out-File all_subs.txt -Encoding utf8
    if (Tool-Exists "puredns") {
        Execute "puredns resolve all_subs.txt -q -w resolved.txt" 2>$null
        if (Test-Path resolved.txt) { Execute "dnsx -l resolved.txt -silent -o scoped_subs.txt" }
        else { Copy-Item all_subs.txt scoped_subs.txt }
    } else { Copy-Item all_subs.txt scoped_subs.txt }
    Mark-Done "subs"
}

function Step-LiveHosts {
    if (-not (Require-File "scoped_subs.txt" "1")) { return }
    if (Step-Done "live") { return }
    Execute "httpx -l scoped_subs.txt -rl $($Config.HttpxRate) -silent -o live_urls.txt"
    Execute "tlsx -l live_urls.txt -silent -o tls.txt" 2>$null
    Mark-Done "live"
}

function Step-URLCollection {
    if (-not (Require-File "live_urls.txt" "2")) { return }
    if (Step-Done "urls") { return }
    if (Tool-Exists "gau") { Execute "gau $Domain --subs -o gau.txt" }
    if (Tool-Exists "waybackurls") { Execute "waybackurls $Domain -o wayback.txt" }
    if (Tool-Exists "katana") { Execute "katana -list live_urls.txt -depth $($Config.KatanaDepth) -silent -o katana.txt" }
    Get-Content gau.txt,wayback.txt,katana.txt -ErrorAction SilentlyContinue | Sort-Object -Unique | Out-File scoped_urls.txt -Encoding utf8
    Mark-Done "urls"
}

function Step-DirectoryBrute {
    if (-not (Require-File "live_urls.txt" "2")) { return }
    New-Item ffuf_results -ItemType Directory -Force | Out-Null
    Get-Content live_urls.txt | Select-Object -First $Config.MaxTargets | ForEach-Object {
        $url = $_.Trim()
        if (-not $url.EndsWith("/")) { $url += "/" }
        $safe = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($url)) -replace '=',''
        Execute "ffuf -u `"$url`FUZZ`" -w $Wordlist -t $($Config.FFUFThreads) -mc 200,301,302,307,308 -timeout 10 -o ffuf_results/ffuf_$safe.json"
    }
}

function Step-NucleiScan {
    if (-not (Require-File "live_urls.txt" "2")) { return }
    Execute "nuclei -l live_urls.txt -rate-limit $($Config.NucleiRate) -severity $NucleiSeverity -o nuclei_results.txt"
}

function Step-XSSScan {
    if (-not (Tool-Exists "dalfox")) { Log "dalfox not available" "WARN"; return }
    if (-not (Require-File "scoped_urls.txt" "3")) { return }
    Get-Content scoped_urls.txt | dalfox pipe --only-poc r --no-color -o dalfox_results.txt
}

function Step-PortScan {
    if (-not (Require-File "scoped_subs.txt" "1")) { return }
    Execute "naabu -list scoped_subs.txt -top-ports $($Config.NaabuPorts) -silent -o ports.txt"
}

function Generate-HTMLReport {
    Log "Generating HTML report..."
    $files = @("scoped_subs.txt","live_urls.txt","scoped_urls.txt","nuclei_results.txt","dalfox_results.txt","ports.txt","tls.txt")
    $html = "<html><head><meta charset='utf-8'><title>Recon Report - $Domain</title><style>body{background:#0d1117;color:#c9d1d9;font-family:Consolas;padding:20px}h1{color:#58a6ff;text-align:center}h2{color:#f0883e}pre{background:#010409;padding:15px;border-radius:8px;max-height:500px;overflow:auto}</style></head><body><h1>Recon Report - $Domain</h1><p>Generated: $(Get-Date)</p>"
    foreach ($f in $files) {
        if (Test-Path $f) {
            $c = Get-Content $f -ErrorAction SilentlyContinue
            $html += "<h2>$f ($($c.Count) lines)</h2><pre>$($c | Select-Object -First 300 | Out-String)</pre>"
        }
    }
    $html += "</body></html>"
    $html | Out-File report.html -Encoding utf8
    Log "Report saved → report.html"
}

# Menu
while ($true) {
    Clear-Host
    Write-Host "════════════════════════════════════════════════" -ForegroundColor Magenta
    Write-Host " Ultimate Recon Framework – $Domain" -ForegroundColor White
    Write-Host "════════════════════════════════════════════════" -ForegroundColor Magenta
    Write-Host "1  Subdomains    2  Live Hosts    3  URLs"
    Write-Host "4  FFUF          5  Nuclei        6  XSS"
    Write-Host "7  Ports         13 Report        x  Exit"
    Write-Host "════════════════════════════════════════════════" -ForegroundColor Magenta

    $c = Read-Host "`nSelect"
    switch ($c) {
        "1"  { Step-Subdomains }
        "2"  { Step-LiveHosts }
        "3"  { Step-URLCollection }
        "4"  { Step-DirectoryBrute }
        "5"  { Step-NucleiScan }
        "6"  { Step-XSSScan }
        "7"  { Step-PortScan }
        "13" { Generate-HTMLReport }
        "x"  { break }
        default { Write-Host "Invalid option" -ForegroundColor Red; Pause }
    }
}
