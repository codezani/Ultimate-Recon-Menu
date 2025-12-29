# Ultimate Recon Menu  
**Interactive Bug Bounty Recon Tool for Windows – Final Edition**  

![Windows](https://img.shields.io/badge/Platform-Windows-blue?logo=windows&logoColor=white)
![PowerShell](https://img.shields.io/badge/Language-PowerShell-5391FE?logo=powershell&logoColor=white)
![License](https://img.shields.io/badge/License-MIT-green)
![Date](https://img.shields.io/badge/Release-December%2029%2C%202025-orange)

A powerful, interactive reconnaissance menu designed specifically for **Bug Bounty hunters** on **Windows**. This tool automates the entire recon workflow using the best open-source tools available in 2025.

### Key Features
- **Auto Scope Filtering** – Automatically keeps only in-scope domains and URLs (no out-of-scope noise)
- **Resume Support** – If interrupted, the script resumes exactly from where it left off
- **Beautiful HTML Report** – Generates a clean, dark-themed `report.html` perfect for bounty submissions or team sharing
- **Interactive Menu** – Run only the steps you need, in any order, without re-running completed stages
- Full recon pipeline coverage:
  - Subdomain Enumeration
  - Live Host Probing (httpx)
  - URL Collection (gau, waybackurls, katana)
  - Directory Brute-force (ffuf)
  - Vulnerability Scanning (nuclei)
  - XSS Scanning (dalfox)
  - JavaScript Analysis (endpoints + secrets)
  - Screenshots (gowitness)
  - Subdomain Takeover Detection
  - Port Scanning (naabu)
  - Parameter Discovery (arjun)
  - GF Pattern Matching

### Prerequisites
All tools must be downloadable executables and added to your **Windows PATH**.

| Tool              | Download Link                                                            |
|-------------------|--------------------------------------------------------------------------|
| subfinder         | https://github.com/projectdiscovery/subfinder/releases                   |
| amass             | https://github.com/owasp-amass/amass/releases                            |
| chaos             | https://github.com/projectdiscovery/chaos-client/releases                |
| httpx             | https://github.com/projectdiscovery/httpx/releases                       |
| katana            | https://github.com/projectdiscovery/katana/releases                      |
| gau               | https://github.com/lc/gau/releases                                       |
| waybackurls       | https://github.com/tomnomnom/waybackurls/releases                        |
| ffuf              | https://github.com/ffuf/ffuf/releases                                    |
| nuclei            | https://github.com/projectdiscovery/nuclei/releases                      |
| dalfox            | https://github.com/hahwul/dalfox/releases                                |
| gowitness         | https://github.com/sensepost/gowitness/releases                          |
| naabu             | https://github.com/projectdiscovery/naabu/releases                       |
| arjun             | https://github.com/s0md3v/Arjun/releases (or `pip install arjun`)        |
| gf                | https://github.com/tomnomnom/gf/releases                                 |
| LinkFinder        | https://github.com/GerbenJavado/LinkFinder                               |
| SecretFinder      | https://github.com/m4ll0k/SecretFinder                                   |

> **Chaos**: Requires a free API key → https://chaos.projectdiscovery.io

### Installation & Setup
1. Download all tools and place them in a folder (e.g., `C:\Tools`).
2. Add that folder to your **Windows PATH**.
3. Create a `wordlists` folder next to the script and place a directory wordlist (e.g., `dir-medium.txt`) inside it.
4. Clone or download the script:
   ```powershell
   git clone https://github.com/yourusername/ultimate-recon-menu.git
   cd ultimate-recon-menu
