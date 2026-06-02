#Requires -RunAsAdministrator
<#
    Ultimate Recon Framework - Windows Edition
    Version: 1.7.0
    Purpose: Authorized security testing / Bug Bounty / Penetration Testing ONLY
    License: MIT
    Warning: Explicit written permission required before scanning any target!
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true, Position=0)]
    [string]$Domain,

    [string]$WordlistDir = "wordlists",

    [string]$NucleiSeverity = "critical,high,medium,low,unknown",

    [string]$Proxy = "",

    [switch]$Auto,

    [switch]$DryRun
)

# ────────────────────────────── Script Information ──────────────────────────────
$ScriptVersion = "1.7.0"
$LastUpdate    = "2026-06-02"

# ────────────────────────────── Validation & Banner ──────────────────────────────
if ($Domain -notmatch '^[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$') {
    Write-Host "ERROR: Invalid domain format (e.g. example.com)" -ForegroundColor Red
    exit 1
}

Clear-Host
Write-Host "════════════════════════════════════════════════════════════════════════════" -ForegroundColor Red
Write-Host "       ULTIMATE RECON FRAMEWORK v$ScriptVersion - WINDOWS EDITION       " -ForegroundColor Yellow
Write-Host " Target : $Domain" -ForegroundColor White
if ($Proxy) { Write-Host " Proxy  : $Proxy" -ForegroundColor Cyan }
if ($Auto)  { Write-Host " Mode   : FULL AUTO PIPELINE" -ForegroundColor Green }
Write-Host "════════════════════════════════════════════════════════════════════════════" -ForegroundColor Red

if (-not $Auto) { 
    Read-Host "Press Enter to confirm you are authorized to test this target" | Out-Null 
}

# ────────────────────────────── Configuration ──────────────────────────────
$Config = @{
    HttpxRate      = 160
    HttpxTimeout   = 15
    HttpxRetries   = 3
    NucleiRate     = 45
    NucleiTimeout  = 15
    FFUFThreads    = 40
    FFUFTimeout    = 8
    KatanaDepth    = 6
    HakrawlerDepth = 5
    GospiderDepth  = 4
    GospiderThreads= 15
    ArjunThreads   = 12
    X8Threads      = 80
    MaxFFUFTargets = 25
    NaabuRate      = 1200
    LogFile        = "recon.log"
    
    AmassTimeout   = 30          # minutes
    AmassDNSQPS    = 100
    AmassMaxQueries= 10000
    JitterMin      = 1
    JitterMax      = 4
    
    UseParallel    = $true
    Screenshot     = $false
    NucleiTemplates= "http/,cves/,vulnerabilities/,takeovers/,exposed-panels/"
}

$BaseDir   = $PSScriptRoot
$OutputDir = Join-Path $BaseDir "$Domain-recon"
New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null
Set-Location $OutputDir

$proxyArg = if ($Proxy) { "-proxy `"$Proxy`"" } else { "" }

$env:PATH = "$PSScriptRoot;$env:USERPROFILE\go\bin;C:\Program Files\Go\bin;$env:PATH"

Write-Host "Current working directory: $(Get-Location)" -ForegroundColor Cyan

# ────────────────────────────── Helper Functions ──────────────────────────────
function Log-Step {
    param([string]$Msg, [string]$Lvl = "INFO")
    $t = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "[$t] [$Lvl] $Msg" | Out-File $Config.LogFile -Append -Encoding utf8
}

function Log-Tool {
    param([string]$Tool, [string]$Action, [string]$Extra = "")
    Log-Step "$Tool $Action $Extra" "TOOL"
}

function Tool-Exists { 
    param([string]$n) 
    return $null -ne (Get-Command $n -ErrorAction SilentlyContinue) 
}

function Execute-Tool {
    param(
        [Parameter(Mandatory=$true)][string]$Cmd,
        [string]$ToolName = $null,
        [string]$OutputFile = $null
    )

    if (-not $ToolName) { $ToolName = ($Cmd -split ' ')[0].Trim() }

    Log-Tool $ToolName "STARTED" "→ $Cmd"
    Write-Host "Executing $ToolName → $Cmd" -ForegroundColor DarkCyan

    if ($DryRun) {
        Log-Tool $ToolName "DRY-RUN"
        return $true
    }

    $success = $false
    try {
        Invoke-Expression $Cmd
        $success = $true
        Log-Tool $ToolName "FINISHED"
        Write-Host "$ToolName finished successfully" -ForegroundColor Green
    }
    catch {
        Log-Tool $ToolName "FAILED" "- $($_.Exception.Message)"
        Write-Host "$ToolName failed: $($_.Exception.Message)" -ForegroundColor Red
    }

    if ($OutputFile -and (Test-Path $OutputFile)) {
        $lines = Get-Content $OutputFile -ErrorAction SilentlyContinue
        $count = if ($lines) { $lines.Count } else { 0 }
        Write-Host "$ToolName output: $count lines → $OutputFile" -ForegroundColor Green
    }

    Start-Sleep -Seconds (Get-Random -Minimum $Config.JitterMin -Maximum $Config.JitterMax)
    return $success
}

function Step-Done { param([string]$n) Test-Path ".done_$n" }
function Mark-Done { param([string]$n) New-Item ".done_$n" -ItemType File -Force | Out-Null }

function Require-File {
    param([string]$f, [string]$s)
    if (-not (Test-Path $f)) {
        Write-Host "Missing file: $f  → Please run step '$s' first" -ForegroundColor Red
        return $false
    }
    return $true
}

# ────────────────────────────── Check Available Tools ──────────────────────────────
$Tools = @(
    "subfinder","amass","assetfinder","findomain","httpx","gau","waymore","waybackurls",
    "katana","hakrawler","gospider","ffuf","nuclei","dalfox","tlsx","dnsx","naabu",
    "fallparams","arjun","paramspider","gf","x8","getJS","linkfinder","qsreplace",
    "trufflehog","gitleaks","gowitness","cloud_enum"
)

foreach ($t in $Tools) {
    if (-not (Tool-Exists $t)) {
        Write-Host "Warning: Tool not found - $t" -ForegroundColor Yellow
    }
}

# ────────────────────────────── Recon Functions ──────────────────────────────

function Step-Subdomains {
    if (Step-Done "subs") { 
        Write-Host "Subdomains enumeration already completed" -ForegroundColor Cyan
        return 
    }

    Log-Step "Subdomains Enumeration" "STARTED"

    # Passive Enumeration
    if (-not (Test-Path "subfinder.txt")) { 
        Execute-Tool "subfinder -d $Domain -all -silent -o subfinder.txt $proxyArg" -OutputFile "subfinder.txt" 
    }
    if (-not (Test-Path "assetfinder.txt")) { 
        Execute-Tool "assetfinder --subs-only $Domain > assetfinder.txt" -OutputFile "assetfinder.txt" 
    }
    if (Tool-Exists "findomain" -and -not (Test-Path "findomain.txt")) { 
        Execute-Tool "findomain -t $Domain -q -u findomain.txt" -OutputFile "findomain.txt" 
    }

    # Amass Passive + Active
    if (-not (Test-Path "amass_passive.txt")) {
        Execute-Tool "amass enum -passive -d $Domain -timeout 1800 -o amass_passive.txt $proxyArg"
    }
    if (-not (Test-Path "amass_active.txt")) {
        Write-Host "[+] Running Amass ACTIVE (may take up to 30 minutes)..." -ForegroundColor Yellow
        Execute-Tool "amass enum -active -d $Domain -timeout 1800 -dns-qps $($Config.AmassDNSQPS) -max-dns-queries $($Config.AmassMaxQueries) -o amass_active.txt $proxyArg"
    }

    # Combine and filter valid subdomains
    if (-not (Test-Path "scoped_subs.txt")) {
        $files = @("subfinder.txt", "amass_passive.txt", "amass_active.txt", "assetfinder.txt", "findomain.txt")
        $all = @()
        foreach ($f in $files) {
            if (Test-Path $f) {
                $content = Get-Content $f -ErrorAction SilentlyContinue | Where-Object {
                    $_ -match '^[a-zA-Z0-9][a-zA-Z0-9.-]*\.[a-zA-Z]{2,}$' -and
                    $_ -notmatch '\s' -and $_ -notmatch '\(' -and $_ -notmatch '-->'
                }
                if ($content) { $all += $content }
            }
        }
        $all | Sort-Object -Unique | Out-File "scoped_subs.txt" -Encoding utf8
        Write-Host "Found $($all.Count) unique subdomains" -ForegroundColor Green
    }

    # Live hosts with httpx
    if (-not (Test-Path "live_subs.txt")) {
        $inputForProbe = if (Test-Path "amass_active.txt") { "amass_active.txt" } else { "scoped_subs.txt" }
        Execute-Tool "Get-Content `"$inputForProbe`" | httpx -silent -threads $($Config.HttpxRate) -timeout 15 -retries 3 -title -status-code -ip -tech-detect -o live_subs.txt $proxyArg"
    }

    # Additional enhancements
    if (Tool-Exists "dnsx" -and -not (Test-Path "dnsx.txt")) {
        Execute-Tool "dnsx -l scoped_subs.txt -silent -a -aaaa -cname -resp -o dnsx.txt"
    }
    if (Tool-Exists "tlsx" -and -not (Test-Path "tlsx.txt")) {
        Execute-Tool "tlsx -l live_subs.txt -silent -san -cn -o tlsx.txt"
    }
    if (-not (Test-Path "takeover.txt")) {
        Execute-Tool "nuclei -l live_subs.txt -t http/takeovers/ -o takeover.txt -silent"
    }

    Mark-Done "subs"
    Log-Step "Subdomains Enumeration" "COMPLETED"
    Write-Host "Subdomains step completed" -ForegroundColor Green
}

function Step-LiveHosts {
    if (-not (Require-File "live_subs.txt" "subdomains")) { return }
    if (Step-Done "live") { Write-Host "Live Hosts already completed" -ForegroundColor Cyan; return }

    Log-Step "Live Hosts Probing" "STARTED"

    $cleanInput = "live_subs_clean.txt"
    if (-not (Test-Path $cleanInput)) {
        Get-Content live_subs.txt | ForEach-Object {
            $line = $_.Trim()
            if ($line -match '^https?://([^/\s\[\]]+)') {
                $matches[1]
            } elseif ($line -match '^[a-zA-Z0-9][a-zA-Z0-9.-]*\.[a-zA-Z]{2,}$') {
                $line
            }
        } | Sort-Object -Unique | Out-File $cleanInput -Encoding utf8
    }

    if (-not (Test-Path "live.json")) {
        Execute-Tool "httpx -l $cleanInput -rl $($Config.HttpxRate) -timeout 30 -retries 3 -title -tech-detect -status-code -web-server -hash sha256 -json -o live.json -follow-redirects $proxyArg"
    }

    if ((Test-Path "live.json") -and (-not (Test-Path "live_urls.txt"))) {
        Get-Content live.json | ConvertFrom-Json | 
            Where-Object { $_.status_code -and $_.status_code -lt 500 } | 
            Select-Object -ExpandProperty url | 
            Out-File live_urls.txt -Encoding utf8
    }

    if (Tool-Exists "naabu") {
        Execute-Tool "naabu -l live_subs.txt -top-ports 1000 -rate $($Config.NaabuRate) -o ports.txt"
    }

    Mark-Done "live"
    Log-Step "Live Hosts" "COMPLETED"
    Write-Host "Live Hosts probing completed" -ForegroundColor Green
}

function Step-URLCollection {
    if (-not (Require-File "live_urls.txt" "livehosts")) { return }
    if (Step-Done "urls") { Write-Host "URL Collection already completed" -ForegroundColor Cyan; return }

    Log-Step "URL Collection" "STARTED"

    if (Tool-Exists "gau" -and -not (Test-Path "gau.txt")) { 
        Execute-Tool "gau $Domain --subs --blacklist png,jpg,woff,css,js > gau.txt" 
    }
    if (Tool-Exists "waymore" -and -not (Test-Path "waymore.txt")) { 
        Execute-Tool "waymore -i $Domain -oU waymore.txt" 
    }
    if (Tool-Exists "waybackurls" -and -not (Test-Path "wayback.txt")) { 
        Execute-Tool "waybackurls $Domain > wayback.txt" 
    }
    if (-not (Test-Path "katana.txt")) { 
        Execute-Tool "katana -list live_urls.txt -d $($Config.KatanaDepth) -jc -silent -o katana.txt -timeout 1800 $proxyArg" 
    }
    if (Tool-Exists "hakrawler" -and -not (Test-Path "hakrawler.txt")) {
        Execute-Tool "Get-Content live_urls.txt | hakrawler -d $($Config.HakrawlerDepth) > hakrawler.txt"
    }
    if (Tool-Exists "gospider" -and -not (Test-Path "gospider_urls.txt")) {
        Remove-Item "gospider_out" -Recurse -Force -ErrorAction SilentlyContinue
        Execute-Tool "gospider -S live_urls.txt -o gospider_out -c $($Config.GospiderThreads) -d $($Config.GospiderDepth) -q --other-source"
        Get-ChildItem "gospider_out" -Recurse -File | Get-Content | Sort-Object -Unique | Out-File gospider_urls.txt
    }

    # Merge all URLs
    if (-not (Test-Path "all_urls.txt")) {
        $files = @("gau.txt","waymore.txt","wayback.txt","katana.txt","hakrawler.txt","gospider_urls.txt")
        $all = @()
        foreach ($f in $files) { 
            if (Test-Path $f) { $all += Get-Content $f -ea 0 } 
        }
        $all | Sort-Object -Unique | Out-File all_urls.txt
    }

    # In-scope filtering
    if (-not (Test-Path "all_urls_inscope.txt")) {
        $scopeParts = @($Domain) + (Get-Content "scoped_subs.txt" -ea 0)
        $scopeRegex = ($scopeParts | ForEach-Object { [regex]::Escape($_) }) -join '|'
        Get-Content all_urls.txt | 
            Where-Object { $_ -match $scopeRegex } | 
            Sort-Object -Unique | 
            Out-File all_urls_inscope.txt -Encoding utf8
    }

    Mark-Done "urls"
    Log-Step "URL Collection" "COMPLETED"
    Write-Host "URL Collection completed" -ForegroundColor Green
}

function Step-ParametersAndJS {
    if (-not (Require-File "all_urls.txt" "urls")) { return }
    if (Step-Done "params_js") { Write-Host "Parameters and JS analysis already completed" -ForegroundColor Cyan; return }

    Log-Step "Parameters and JS Analysis" "STARTED"
    New-Item -ItemType Directory -Force -Path "params_js" | Out-Null

    $arjunInput = "all_urls.txt"

    if (Tool-Exists "fallparams" -and -not (Test-Path "params_js/fall.txt")) {
        Execute-Tool "fallparams -u $arjunInput -c -d 3 -t 20 -o params_js/fall.txt"
    }
    if (Tool-Exists "arjun" -and -not (Test-Path "params_js/arjun.json")) {
        Execute-Tool "arjun -i $arjunInput -t $($Config.ArjunThreads) -oT params_js/arjun.json"
    }
    if (Tool-Exists "paramspider" -and -not (Test-Path "params_js/paramspider.txt")) {
        Execute-Tool "paramspider -d $Domain > params_js/paramspider.txt"
    }

    # Combine parameters
    if (-not (Test-Path "params_all.txt")) {
        Get-ChildItem "params_js" -File -Filter "*.txt" -ea 0 | Get-Content | Sort-Object -Unique | Out-File params_all.txt
    }

    if (Tool-Exists "getJS" -and -not (Test-Path "params_js/js_files.txt")) {
        Execute-Tool "Get-Content all_urls.txt | getJS --complete > params_js/js_files.txt"
    }
    if (Tool-Exists "linkfinder" -and (Test-Path "params_js/js_files.txt") -and -not (Test-Path "params_js/endpoints.txt")) {
        Execute-Tool "Get-Content params_js/js_files.txt | linkfinder -o cli -d > params_js/endpoints.txt"
    }

    if (Tool-Exists "qsreplace" -and -not (Test-Path "params_js/urls_with_fuzz.txt")) {
        Execute-Tool "Get-Content all_urls.txt | qsreplace `"FUZZ`" > params_js/urls_with_fuzz.txt"
    }

    Mark-Done "params_js"
    Log-Step "ParametersAndJS" "COMPLETED"
    Write-Host "Parameters and JS analysis completed" -ForegroundColor Green
}

function Step-X8Fuzz {
    if (-not (Require-File "live_urls.txt" "livehosts")) { return }
    if (-not (Tool-Exists "x8")) { Write-Host "x8 not found" -ForegroundColor Yellow; return }
    if (Step-Done "x8") { Write-Host "x8 fuzzing already completed" -ForegroundColor Cyan; return }

    Log-Step "x8 Parameter Fuzzing" "STARTED"

    $wordlist = if (Test-Path "params_all.txt") { "params_all.txt" } else { "$WordlistDir/params-top.txt" }
    if (-not (Test-Path $wordlist)) { 
        Write-Host "No wordlist found for x8" -ForegroundColor Yellow
        return 
    }

    Get-Content live_urls.txt | ForEach-Object {
        $url = $_.Trim()
        if ($url) {
            Execute-Tool "x8 -u `"$url`" -w `"$wordlist`" -t $($Config.X8Threads) --append -o x8_results.txt $proxyArg"
        }
    }

    Mark-Done "x8"
    Log-Step "x8 Fuzzing" "COMPLETED"
}

function Step-DirectoryBrute {
    if (-not (Require-File "live_urls.txt" "livehosts")) { return }
    $wordlist = Join-Path $BaseDir "$WordlistDir\dir-medium.txt"
    if (-not (Test-Path $wordlist)) { 
        Write-Host "Directory wordlist missing" -ForegroundColor Yellow
        return 
    }
    if (Step-Done "ffuf") { Write-Host "FFUF already completed" -ForegroundColor Cyan; return }

    Log-Step "FFUF Directory Brute Force" "STARTED"

    Get-Content live_urls.txt -First $Config.MaxFFUFTargets | ForEach-Object {
        $url = $_.Trim()
        if (-not $url.EndsWith("/")) { $url += "/" }
        $safe = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($url)) -replace '[=/+]', ''
        $outFile = "ffuf_$safe.json"
        if (-not (Test-Path $outFile)) {
            Execute-Tool "ffuf -u `"$url`FUZZ`" -w `"$wordlist`" -t $($Config.FFUFThreads) -timeout 1800 -mc 200,301,302,307,308,401,403 -ac -r -o $outFile $proxyArg"
        }
    }

    Mark-Done "ffuf"
    Log-Step "FFUF Directory Brute" "COMPLETED"
    Write-Host "Directory brute force completed" -ForegroundColor Green
}

function Step-NucleiScan {
    if (-not (Require-File "live_urls.txt" "livehosts")) { return }
    if (Step-Done "nuclei") { Write-Host "Nuclei scan already completed" -ForegroundColor Cyan; return }

    Log-Step "Nuclei Vulnerability Scan" "STARTED"

    if (-not (Test-Path "nuclei_results.txt")) {
        Execute-Tool "nuclei -l live_urls.txt -severity $NucleiSeverity -rl $($Config.NucleiRate) -timeout 1800 -o nuclei_results.txt $proxyArg"
    }

    Mark-Done "nuclei"
    Log-Step "Nuclei Scan" "COMPLETED"
    Write-Host "Nuclei scan completed" -ForegroundColor Green
}

function Step-XSSScan {
    if (-not (Require-File "all_urls.txt" "urls")) { return }
    if (-not (Tool-Exists "dalfox")) { Write-Host "dalfox not found" -ForegroundColor Yellow; return }
    if (Step-Done "xss") { Write-Host "XSS scan already completed" -ForegroundColor Cyan; return }

    Log-Step "Dalfox XSS Scan" "STARTED"

    if (-not (Test-Path "dalfox_results.txt")) {
        Execute-Tool "Get-Content all_urls.txt | dalfox pipe --only-poc --delay 300 -o dalfox_results.txt"
    }

    Mark-Done "xss"
    Log-Step "XSS Scan" "COMPLETED"
    Write-Host "XSS scan completed" -ForegroundColor Green
}

# ────────────────────────────── New Enhanced Modules ──────────────────────────────

function Step-CloudEnum {
    if (Step-Done "cloud") { return }
    Log-Step "Cloud Enumeration" "STARTED"
    if (Tool-Exists "cloud_enum") {
        Execute-Tool "cloud_enum -k $Domain -l cloud_results.txt"
    }
    Mark-Done "cloud"
}

function Step-Screenshots {
    if (-not $Config.Screenshot) { return }
    if (Step-Done "screenshot") { return }
    New-Item -ItemType Directory -Force -Path "screenshots" | Out-Null
    if (Tool-Exists "gowitness") {
        Execute-Tool "gowitness file -f live_urls.txt -D screenshots/ --threads 20"
    }
    Mark-Done "screenshot"
}

function Step-SecretScan {
    if (-not (Test-Path "all_urls.txt")) { return }
    Log-Step "Secret Scanning" "STARTED"
    if (Tool-Exists "trufflehog") {
        Execute-Tool "trufflehog filesystem . --json > secrets.json"
    }
    Mark-Done "secret"
}

# ────────────────────────────── Advanced Report ──────────────────────────────
function Generate-Report {
    Log-Step "Report Generation" "STARTED"

    $stats = @{
        Subdomains     = (Get-Content scoped_subs.txt -ea 0 | Measure-Object -Line).Lines
        LiveHosts      = (Get-Content live_urls.txt -ea 0 | Measure-Object -Line).Lines
        TotalURLs      = (Get-Content all_urls.txt -ea 0 | Measure-Object -Line).Lines
        NucleiCritical = (Select-String -Path nuclei_results.txt -Pattern "\[critical\]" -ea 0 | Measure-Object).Count
        Takeovers      = (Get-Content takeover.txt -ea 0 | Measure-Object -Line).Lines
    }

    $html = @"
<html><head><meta charset='utf-8'><title>Recon Report - $Domain</title>
<style>
    body {background:#0d1117;color:#c9d1d9;font-family:Consolas;padding:20px;}
    h1 {color:#58a6ff;text-align:center;}
    h2 {color:#f0883e;}
    pre {background:#010409;padding:15px;border-radius:8px;overflow:auto;}
</style></head>
<body>
<h1>Ultimate Recon Report – $Domain (v$ScriptVersion)</h1>
<p>Generated: $(Get-Date)</p>
<h2>Statistics</h2><pre>$($stats | ConvertTo-Json -Depth 3)</pre>
"@

    $files = @("scoped_subs.txt","live_subs.txt","live_urls.txt","all_urls.txt","params_all.txt","nuclei_results.txt","takeover.txt","dalfox_results.txt")
    foreach ($f in $files) {
        if (Test-Path $f) {
            $count = (Get-Content $f -ea 0 | Measure-Object -Line).Lines
            $content = Get-Content $f -First 250 -ea 0 | Out-String
            $html += "<h2>$f ($count lines)</h2><pre>$content</pre>"
        }
    }

    $html += "</body></html>"
    $html | Out-File "report_$((Get-Date).ToString('yyyyMMdd_HHmm')).html" -Encoding utf8

    Write-Host "Full HTML Report generated successfully!" -ForegroundColor Green
}

# ────────────────────────────── Full Auto Pipeline ──────────────────────────────
function Run-FullAuto {
    Write-Host "Starting FULL AUTO PIPELINE v$ScriptVersion" -ForegroundColor Magenta
    
    Step-Subdomains
    Step-LiveHosts
    Step-URLCollection
    Step-ParametersAndJS
    Step-X8Fuzz
    Step-DirectoryBrute
    Step-NucleiScan
    Step-XSSScan
    Step-CloudEnum
    Step-Screenshots
    Step-SecretScan
    Generate-Report

    Write-Host "FULL AUTO PIPELINE COMPLETED SUCCESSFULLY!" -ForegroundColor Magenta
}

# ────────────────────────────── Main Menu ──────────────────────────────
if ($Auto) {
    Run-FullAuto
    exit
}

while ($true) {
    Clear-Host
    Write-Host "═══════════════════════════════════════════════════════" -ForegroundColor Magenta
    Write-Host " Ultimate Recon Framework v$ScriptVersion - $Domain" -ForegroundColor White
    Write-Host "═══════════════════════════════════════════════════════" -ForegroundColor Magenta
    Write-Host " 1  Subdomains Enumeration"
    Write-Host " 2  Live Hosts + Port Scan"
    Write-Host " 3  URL Collection"
    Write-Host " 4  Parameters + JS Analysis"
    Write-Host " 5  x8 Fuzzing"
    Write-Host " 6  FFUF Directory Brute"
    Write-Host " 7  Nuclei Vulnerability Scan"
    Write-Host " 8  XSS Scan (dalfox)"
    Write-Host " 9  Cloud Enum + Secret Scan"
    Write-Host "10  Take Screenshots"
    Write-Host "11  Generate Full Report"
    Write-Host "12  FULL AUTO (All Steps)"
    Write-Host " x  Exit"
    Write-Host "═══════════════════════════════════════════════════════" -ForegroundColor Magenta

    $choice = Read-Host "Select option"

    switch ($choice) {
        "1"  { Step-Subdomains }
        "2"  { Step-LiveHosts }
        "3"  { Step-URLCollection }
        "4"  { Step-ParametersAndJS }
        "5"  { Step-X8Fuzz }
        "6"  { Step-DirectoryBrute }
        "7"  { Step-NucleiScan }
        "8"  { Step-XSSScan }
        "9"  { Step-CloudEnum; Step-SecretScan }
        "10" { Step-Screenshots }
        "11" { Generate-Report }
        "12" { Run-FullAuto }
        "x"  { 
            Write-Host "`nSession ended. All results saved in: $OutputDir" -ForegroundColor Green
            break 
        }
        default { Write-Host "Invalid option" -ForegroundColor Red; Start-Sleep -Seconds 1 }
    }

    if ($choice -ne "x") {
        Read-Host "`nPress Enter to continue..."
    }
}
