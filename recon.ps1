<#
 Ultimate Interactive Bug Bounty Recon Menu
 FINAL EDITION – AutoScope + Resume + HTML Report
 Date: Dec 29, 2025
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [string]$Domain,

    [string]$Wordlist = "wordlists\dir-medium.txt"
)

# ─────────────────────────────── Setup ───────────────────────────────
$OutputDir = "$Domain-recon"
New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null
Set-Location $OutputDir

function Test-Tool($n) { $null -ne (Get-Command $n -ErrorAction SilentlyContinue) }
function Pause { Read-Host "`nPress Enter to continue..." | Out-Null }

# Resume helpers
function Step-Done($n) { Test-Path ".done_$n" }
function Mark-Step($n) { New-Item ".done_$n" -ItemType File -Force | Out-Null }

# Scope filter
function Filter-Scope {
    param($InputFile, $OutputFile)
    if (-not (Test-Path $InputFile)) { return }
    Get-Content $InputFile |
        Where-Object { $_ -match "([a-zA-Z0-9\-]+\.)*$([regex]::Escape($Domain))" } |
        Sort-Object -Unique |
        Out-File $OutputFile -Encoding utf8
}

# HTML report
function Generate-HTMLReport {
    $sections = @(
        @{Title="Subdomains"; File="scoped_subs.txt"},
        @{Title="Live Hosts"; File="live_urls.txt"},
        @{Title="URLs"; File="scoped_urls.txt"},
        @{Title="Nuclei Findings"; File="nuclei_results.txt"},
        @{Title="XSS (Dalfox)"; File="dalfox.txt"},
        @{Title="JS Secrets"; File="js_secrets.txt"},
        @{Title="Takeovers"; File="takeover.txt"},
        @{Title="Open Ports"; File="ports.txt"}
    )

$html = @"
<html>
<head>
<title>Recon Report - $Domain</title>
<style>
body { font-family: Consolas; background:#111; color:#eee; }
h1 { color:#00ffcc; }
h2 { color:#ffaa00; }
pre { background:#1e1e1e; padding:10px; overflow:auto; }
</style>
</head>
<body>
<h1>Recon Report - $Domain</h1>
<p>Generated: $(Get-Date)</p>
"@

    foreach ($s in $sections) {
        if (Test-Path $s.File) {
            $c = Get-Content $s.File -ErrorAction SilentlyContinue | Select-Object -First 500
            $html += "<h2>$($s.Title)</h2><pre>$($c -join "`n")</pre>"
        }
    }

    $html += "</body></html>"
    $html | Out-File "report.html" -Encoding utf8
}

# ─────────────────────────────── Menu ───────────────────────────────
while ($true) {
    Clear-Host
    Write-Host "════════════════════════════════════════════" -ForegroundColor Magenta
    Write-Host " Ultimate Recon Menu → $Domain" -ForegroundColor White
    Write-Host "════════════════════════════════════════════" -ForegroundColor Magenta
    Write-Host "1  Subdomain Enumeration"
    Write-Host "2  Live Hosts (httpx)"
    Write-Host "3  URL Collection"
    Write-Host "4  Directory Bruteforce (ffuf)"
    Write-Host "5  Nuclei Scan"
    Write-Host "6  XSS Scan (dalfox)"
    Write-Host "7  JavaScript Analysis"
    Write-Host "8  Screenshots (gowitness)"
    Write-Host "9  Subdomain Takeover"
    Write-Host "10 Port Scan (naabu)"
    Write-Host "11 Parameter Discovery (arjun)"
    Write-Host "12 GF Pattern Matching"
    Write-Host "13 Generate HTML Report"
    Write-Host "0  Summary"
    Write-Host "x  Exit"
    $c = Read-Host "`nSelect"

switch ($c) {

"1" {
    if (-not (Step-Done "subs")) {
        subfinder -d $Domain -all -silent -o subs_subfinder.txt
        amass enum -passive -d $Domain -o subs_amass.txt
        if ($env:CHAOS_KEY) { chaos -d $Domain -silent -o subs_chaos.txt }

        Get-Content subs_*.txt | Sort-Object -Unique | Out-File all_subs.txt
        Filter-Scope all_subs.txt scoped_subs.txt
        Mark-Step "subs"
    }
    Pause
}

"2" {
    if (-not (Step-Done "live")) {
        httpx -l scoped_subs.txt -silent -o live_urls.txt
        httpx -l scoped_subs.txt -title -status-code -tech-detect -silent -o live_info.txt
        Mark-Step "live"
    }
    Pause
}

"3" {
    if (-not (Step-Done "urls")) {
        if (Test-Tool "gau") { gau $Domain --subs | Out-File gau.txt }
        if (Test-Tool "waybackurls") { waybackurls $Domain | Out-File wayback.txt }
        if (Test-Tool "katana") { katana -list live_urls.txt -depth 4 -silent -o katana.txt }

        Get-Content gau.txt,wayback.txt,katana.txt -ErrorAction SilentlyContinue |
            Sort-Object -Unique | Out-File all_urls.txt

        Filter-Scope all_urls.txt scoped_urls.txt
        Mark-Step "urls"
    }
    Pause
}

"4" {
    New-Item -ItemType Directory -Force ffuf_results | Out-Null
    Get-Content live_urls.txt | Select-Object -First 8 | ForEach-Object {
        $safe = ($_ -replace 'https?://','' -replace '[^a-zA-Z0-9]','_')
        ffuf -u "$_/FUZZ" -w $Wordlist -mc 200,301,302,307,308 -silent `
            -o "ffuf_results/$safe.json"
    }
    Pause
}

"5" {
    nuclei -update-templates
    nuclei -l live_urls.txt -severity critical,high,medium -silent |
        Out-File nuclei_results.txt
    Pause
}

"6" {
    Get-Content live_urls.txt |
        dalfox pipe --skip-bav --only-poc --no-color |
        Out-File dalfox.txt
    Pause
}

"7" {
    katana -list live_urls.txt -extension js -silent | Out-File js_katana.txt
    gau $Domain --subs | Select-String "\.js" -Raw | Out-File js_gau.txt
    waybackurls $Domain | Select-String "\.js" -Raw | Out-File js_wayback.txt

    Get-Content js_*.txt | Sort-Object -Unique | Out-File js_files.txt

    if (Test-Path "C:\Tools\LinkFinder\linkfinder.py") {
        Get-Content js_files.txt |
            ForEach-Object { python C:\Tools\LinkFinder\linkfinder.py -i $_ -o cli } |
            Sort-Object -Unique | Out-File js_endpoints.txt
    }

    if (Test-Path "C:\Tools\SecretFinder\SecretFinder.py") {
        Get-Content js_files.txt |
            ForEach-Object { python C:\Tools\SecretFinder\SecretFinder.py -i $_ -o cli } |
            Sort-Object -Unique | Out-File js_secrets.txt
    }
    Pause
}

"8" {
    gowitness file -f live_urls.txt --threads 20 --timeout 20
    Pause
}

"9" {
    nuclei -l scoped_subs.txt -t takeovers -silent | Out-File takeover.txt
    Pause
}

"10" {
    naabu -list scoped_subs.txt -top-ports 1000 -silent | Out-File ports.txt
    Pause
}

"11" {
    New-Item -ItemType Directory -Force arjun_results | Out-Null
    Get-Content scoped_urls.txt | Select-Object -First 20 | ForEach-Object {
        $safe = ($_ -replace '[^a-zA-Z0-9]','_')
        $safe = $safe.Substring(0,[Math]::Min(40,$safe.Length))
        arjun -u $_ -oT "arjun_results/$safe.txt"
    }
    Pause
}

"12" {
    New-Item -ItemType Directory -Force gf_matches | Out-Null
    foreach ($p in "xss","ssrf","lfi","rce","redirect","takeover","s3-buckets","debug-pages") {
        gf $p scoped_urls.txt | Out-File "gf_matches/$p.txt"
    }
    Pause
}

"13" {
    Generate-HTMLReport
    Write-Host "HTML report generated → report.html" -ForegroundColor Green
    Pause
}

"0" {
    Get-ChildItem *.txt | ForEach-Object {
        Write-Host "$($_.Name): $((Get-Content $_).Count) lines"
    }
    Pause
}

"x" { return }
default { Pause }

}
}
