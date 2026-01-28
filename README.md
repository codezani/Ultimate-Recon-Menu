# Ultimate Recon Framework – Windows Edition

**Fast, safe, and interactive reconnaissance pipeline for authorized security testing only.**

A PowerShell-based framework optimized for Windows environments, designed for bug bounty hunters, penetration testers, and red teamers who have **explicit permission** to test targets.

**Important Legal Notice**  
This tool is provided **strictly for authorized use only** (bug bounty programs, penetration testing engagements with written permission). Unauthorized scanning is illegal. Always confirm authorization before running.

## Features

- Interactive menu-driven workflow
- Step-by-step recon pipeline:  
  1. Subdomain enumeration  
  2. Live host probing  
  3. URL collection (historical + crawling)  
  4. Parameter discovery  
  5. Directory brute-forcing  
  6. Vulnerability scanning (Nuclei)  
  7. XSS testing (Dalfox)  
  8. Port scanning  
- Progress tracking with `.done_*` marker files  
- Rate limiting, timeouts, and retries for stability  
- Simple HTML report generation  
- Dry-run mode (`-DryRun`) for testing commands without execution  
- Wordlist auto-check with helpful setup instructions

### Tools Integrated

| Category              | Tools                                      | Purpose                              |
|-----------------------|--------------------------------------------|--------------------------------------|
| Subdomain Enum        | subfinder, amass, puredns, dnsx            | Passive & resolved subdomains        |
| Probing               | httpx, tlsx                                | Live hosts, titles, tech detection, TLS info |
| Crawling / URLs       | gau, waybackurls, katana, gospider         | Historical + active URL collection   |
| Parameters            | fallparams                                 | Hidden parameter discovery           |
| Brute-force           | ffuf                                       | Directory / file brute-forcing       |
| Vulnerability Scan    | nuclei                                     | Template-based vuln detection        |
| XSS                   | dalfox                                     | Reflected & blind XSS hunting        |
| Ports                 | naabu                                      | Top ports scanning                   |

## Requirements

- Windows 10 / 11  
- PowerShell 5.1+ (or PowerShell 7 recommended)  
- **Go 1.21+** installed (https://go.dev/dl/)  
- **Git** installed (https://git-scm.com/download/win)  
- Run scripts **as Administrator** (required for network tools stability)

## Installation

1. Clone the repository:
   ```powershell
   git clone https://github.com/codezani/ultimate-recon-windows.git
   cd ultimate-recon-windows
