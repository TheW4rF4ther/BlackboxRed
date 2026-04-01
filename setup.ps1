<#
.SYNOPSIS
    Blackbox Intelligence Group LLC - CommandoVM Red Team Setup Script
    Interactive category/package selector + one-click installer launcher.

.DESCRIPTION
    This script:
      1. Validates pre-install requirements
      2. Presents an interactive category/package selection menu
      3. Generates a filtered BlackboxRed-Custom.xml based on your selections
            4. Prepares a configurable installer source (local or git clone)
            5. Injects generated profile and Blackbox RED wallpaper branding
            6. Launches the installer

.PARAMETER SkipClone
    Do not clone/update installer source. Requires a valid local InstallerRoot.

.PARAMETER InstallerRoot
    Local path to the Commando-compatible installer source tree.
    Must contain install.ps1, Images, and Profiles.

.PARAMETER InstallerRepoUrl
    Optional git URL used to clone installer source into InstallerRoot when missing.

.PARAMETER NoPassword
    Pass when the Windows account has no password set.

.PARAMETER SkipChecks
    Bypass pre-install validation (NOT recommended).

.PARAMETER CLI
    Launch CommandoVM installer in headless CLI mode (no GUI).

.PARAMETER UseGui
    Enable a Windows Forms package selection interface for fine-tuning.

.PARAMETER Password
    Windows account password for Boxstarter reboot-resilience (CLI mode).

.EXAMPLE
    .\setup.ps1
    .\setup.ps1 -UseGui
    .\setup.ps1 -CLI -Password "YourPassword"
    .\setup.ps1 -SkipClone -SkipChecks
#>

[CmdletBinding()]
param (
    [switch]$SkipClone,
    [switch]$NoPassword,
    [switch]$SkipChecks,
    [switch]$CLI,
    [switch]$UseGui,
    [string]$Password = "",
    [string]$InstallerRoot = "",
    [string]$InstallerRepoUrl = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Test-IsAdministrator {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Escape-Argument {
    param([string]$Value)
    if ($null -eq $Value) { return '""' }
    return '"' + ($Value -replace '"', '""') + '"'
}

function Restart-ElevatedIfNeeded {
    if (Test-IsAdministrator) { return }

    Write-Host "[!] Administrator privileges are required. Relaunching elevated..." -ForegroundColor Yellow

    $argList = @(
        "-NoProfile",
        "-ExecutionPolicy", "Bypass",
        "-File", (Escape-Argument -Value $PSCommandPath)
    )

    if ($SkipClone.IsPresent) { $argList += "-SkipClone" }
    if ($NoPassword.IsPresent) { $argList += "-NoPassword" }
    if ($SkipChecks.IsPresent) { $argList += "-SkipChecks" }
    if ($CLI.IsPresent) { $argList += "-CLI" }
    if ($UseGui.IsPresent) { $argList += "-UseGui" }

    if ($Password -ne "") {
        $argList += "-Password"
        $argList += (Escape-Argument -Value $Password)
    }

    if ($InstallerRoot -ne "") {
        $argList += "-InstallerRoot"
        $argList += (Escape-Argument -Value $InstallerRoot)
    }

    if ($InstallerRepoUrl -ne "") {
        $argList += "-InstallerRepoUrl"
        $argList += (Escape-Argument -Value $InstallerRepoUrl)
    }

    $psi = @{
        FilePath = "powershell.exe"
        ArgumentList = ($argList -join " ")
        Verb = "RunAs"
        WindowStyle = "Normal"
    }

    Start-Process @psi | Out-Null
    exit 0
}

Restart-ElevatedIfNeeded

# ---------------------------------------------------------------------------
# CONFIGURATION
# ---------------------------------------------------------------------------
$InstallerRoot    = if ([string]::IsNullOrWhiteSpace($InstallerRoot)) { Join-Path $PSScriptRoot "BlackboxRed-Core" } else { $InstallerRoot }
$GeneratedProfile = Join-Path $PSScriptRoot "Profiles\BlackboxRed-Custom.xml"
$ProfileDest      = Join-Path $InstallerRoot "Profiles\BlackboxRed-Custom.xml"
$InstallScript    = Join-Path $InstallerRoot "install.ps1"
$WallpaperSource  = Join-Path $PSScriptRoot "Assets\blackboxredwallpaper.png"

# ---------------------------------------------------------------------------
# PACKAGE CATALOG  (ordered: category -> package list)
# Each entry: @{ Name="display name"; Pkg="chocolatey-id"; Note="description" }
# ---------------------------------------------------------------------------
$Catalog = [ordered]@{

    "Utilities & Productivity" = @(
        @{ Name="Notepad++";               Pkg="notepadplusplus.vm";             Note="Enhanced text editor"                 }
        @{ Name="7-Zip";                   Pkg="7zip-15-05.vm";                  Note="Archive utility"                      }
        @{ Name="Cmder";                   Pkg="cmder.vm";                       Note="Enhanced Windows terminal"            }
        @{ Name="VS Code";                 Pkg="vscode";                         Note="Code editor"                          }
        @{ Name="Google Chrome";           Pkg="googlechrome";                   Note="Browser"                              }
        @{ Name="Firefox";                 Pkg="firefox";                        Note="Browser"                              }
        @{ Name="Git";                     Pkg="git";                            Note="Version control"                      }
        @{ Name="Obsidian";                Pkg="obsidian";                       Note="Markdown knowledge base"              }
        @{ Name="KeePass";                 Pkg="keepass";                        Note="Password manager"                     }
        @{ Name="Greenshot";               Pkg="greenshot";                      Note="Screenshot tool"                      }
        @{ Name="OpenVPN";                 Pkg="openvpn.vm";                     Note="VPN client"                           }
        @{ Name="WinSCP";                  Pkg="winscp.vm";                      Note="SCP/SFTP client"                      }
        @{ Name="VNC Viewer";              Pkg="vnc-viewer.vm";                  Note="Remote desktop viewer"                }
        @{ Name="Telnet";                  Pkg="telnet.vm";                      Note="Telnet client"                        }
    )

    "Development -- Payload Compilation" = @(
        @{ Name="Go";                      Pkg="golang";                         Note="Modern C2/implant compilation"        }
        @{ Name="Rust";                    Pkg="rust";                           Note="Memory-safe implant development"      }
        @{ Name="Nim";                     Pkg="nim";                            Note="Lightweight AV-evasive compilation"   }
        @{ Name="Python 3";                Pkg="python3";                        Note="Scripting and tooling"                }
        @{ Name="Visual Studio";           Pkg="visualstudio.vm";                Note=".NET / C++ compilation suite"         }
        @{ Name="VC Build Tools";          Pkg="vcbuildtools.vm";                Note="MSVC compiler toolchain"              }
        @{ Name="NASM";                    Pkg="nasm.vm";                        Note="x86/x64 assembler"                    }
    )

    "Network Reconnaissance" = @(
        @{ Name="Nmap";                    Pkg="nmap.vm";                        Note="Port/service scanner"                 }
        @{ Name="Gobuster";                Pkg="gobuster.vm";                    Note="Directory/DNS brute-forcer"           }
        @{ Name="Kerbrute";                Pkg="kerbrute.vm";                    Note="Kerberos user enumeration"            }
        @{ Name="GoWitness";               Pkg="gowitness.vm";                   Note="Web screenshot recon"                 }
        @{ Name="Snaffler";                Pkg="snaffler.vm";                    Note="Network share credential hunter"      }
        @{ Name="LDAPNomNom";              Pkg="ldapnomnom.vm";                  Note="LDAP user enumeration"                }
        @{ Name="Group3r";                 Pkg="group3r.vm";                     Note="GPO misconfiguration scanner"         }
        @{ Name="NetGPPPassword";          Pkg="netgpppassword.vm";              Note="GPP credential extractor"             }
        @{ Name="MFASweep";                Pkg="mfasweep.vm";                    Note="MFA bypass testing"                   }
        @{ Name="Likely Usernames";        Pkg="statistically-likely-usernames.vm"; Note="Username wordlists"               }
    )

    "Web & Database" = @(
        @{ Name="CyberChef";               Pkg="cyberchef.vm";                   Note="Encode/decode/transform data"         }
        @{ Name="ExifTool";                Pkg="exiftool.vm";                    Note="Metadata extractor"                   }
        @{ Name="FuzzDB";                  Pkg="fuzzdb.vm";                      Note="Fuzzing wordlists"                    }
        @{ Name="PayloadsAllTheThings";    Pkg="payloadsallthethings.vm";        Note="Payload/bypass cheat sheets"          }
        @{ Name="SecLists";                Pkg="seclists.vm";                    Note="Security testing wordlists"           }
        @{ Name="SQLRecon";                Pkg="sqlrecon.vm";                    Note="MSSQL attack framework"               }
        @{ Name="PowerUpSQL";              Pkg="powerupsql.vm";                  Note="SQL Server privilege escalation"      }
        @{ Name="SQLite Browser";          Pkg="sqlitebrowser.vm";               Note="SQLite database viewer"               }
    )

    "Active Directory & Identity" = @(
        @{ Name="BloodHound";              Pkg="bloodhound.vm";                  Note="AD attack path visualizer"            }
        @{ Name="SharpHound";              Pkg="sharphound.vm";                  Note="BloodHound data collector"            }
        @{ Name="BH Custom Queries";       Pkg="bloodhound-custom-queries.vm";   Note="Extended BloodHound queries"          }
        @{ Name="ADConnectDump";           Pkg="adconnectdump.vm";               Note="Azure AD Connect credential dump"     }
        @{ Name="SharpView";               Pkg="sharpview.vm";                   Note=".NET PowerView port"                  }
        @{ Name="Certify";                 Pkg="certify.vm";                     Note="AD CS misconfiguration finder"        }
        @{ Name="Whisker";                 Pkg="whisker.vm";                     Note="Shadow credentials attack"            }
        @{ Name="PetitPotam";              Pkg="petitpotam.vm";                  Note="NTLM coerce via EFS"                  }
        @{ Name="SpoolSample";             Pkg="spoolsample.vm";                 Note="Printer bug coercion"                 }
        @{ Name="RouteSixtySink";          Pkg="routesixtysink.vm";              Note="NBNS/mDNS poisoning"                  }
        @{ Name="PowerMad";                Pkg="powermad.vm";                    Note="MachineAccountQuota attacks"          }
        @{ Name="PowerSploit";             Pkg="powersploit.vm";                 Note="PowerShell post-exploitation"         }
    )

    "Cloud -- Azure / AWS / Entra ID" = @(
        @{ Name="AzureHound";              Pkg="azurehound.vm";                  Note="BloodHound for Azure / Entra ID"      }
        @{ Name="TeamFiltration";          Pkg="teamfiltration.vm";              Note="M365 / Teams enumeration & spray"     }
        @{ Name="Az PowerShell";           Pkg="az.powershell";                  Note="Azure PowerShell module"              }
        @{ Name="Azure CLI";               Pkg="azure-cli";                      Note="Azure command-line interface"         }
        @{ Name="AWS CLI";                 Pkg="awscli";                         Note="Amazon Web Services CLI"              }
        @{ Name="MicroBurst";              Pkg="microburst.vm";                  Note="Azure security assessment toolkit"    }
        @{ Name="PowerZure";               Pkg="powerzure.vm";                   Note="Azure post-exploitation framework"    }
        @{ Name="MailSniper";              Pkg="mailsniper.vm";                  Note="Exchange/O365 password spray"         }
    )

    "Privilege Escalation" = @(
        @{ Name="SharpUp";                 Pkg="sharpup.vm";                     Note="Local privilege escalation checks"    }
        @{ Name="JuicyPotato";             Pkg="juicypotato.vm";                 Note="Token impersonation / PrivEsc"        }
        @{ Name="Seatbelt";                Pkg="seatbelt.vm";                    Note="Host security situational awareness"  }
    )

    "Credential Access" = @(
        @{ Name="Mimikatz";                Pkg="mimikatz.vm";                    Note="LSASS credential dumping"             }
        @{ Name="SafetyKatz";              Pkg="safetykatz.vm";                  Note="minidump + Mimikatz in-memory"        }
        @{ Name="Rubeus";                  Pkg="rubeus.vm";                      Note="Kerberos attack toolkit"              }
        @{ Name="SharpDPAPI";              Pkg="sharpdpapi.vm";                  Note="DPAPI secret decryption"              }
        @{ Name="SharpSecDump";            Pkg="sharpsecdump.vm";                Note="Remote SAM/LSA dump"                  }
        @{ Name="SharpLAPS";               Pkg="sharplaps.vm";                   Note="LAPS password retrieval"              }
        @{ Name="CredNinja";               Pkg="credninja.vm";                   Note="Credential validation across hosts"   }
        @{ Name="Inveigh";                 Pkg="inveigh.vm";                     Note="LLMNR/NBNS/mDNS poisoning"            }
        @{ Name="ASREPRoast";              Pkg="asreproast.vm";                  Note="AS-REP roasting attacks"              }
        @{ Name="KeeThief";                Pkg="keethief.vm";                    Note="KeePass credential extraction"        }
        @{ Name="GetLAPSPasswords";        Pkg="getlapspasswords.vm";            Note="LAPS password enumeration"            }
        @{ Name="Dumpert";                 Pkg="dumpert.vm";                     Note="Direct syscall LSASS dumper"          }
        @{ Name="MiniDump";                Pkg="minidump.vm";                    Note="Process memory dumping"               }
        @{ Name="NanoDump";                Pkg="nanodump.vm";                    Note="LSASS minidump (evasive)"             }
    )

    "Lateral Movement & Execution" = @(
        @{ Name="SharpExec";               Pkg="sharpexec.vm";                   Note="Remote execution via WMI/SMB/DCOM"   }
        @{ Name="WMImplant";               Pkg="wmimplant.vm";                   Note="WMI-based lateral movement"          }
        @{ Name="SharpWMI";                Pkg="sharpwmi.vm";                    Note="WMI remote execution"                }
        @{ Name="ProcessDump";             Pkg="processdump.vm";                 Note="Process memory dump utility"         }
        @{ Name="StreamDivert";            Pkg="streamdivert.vm";                Note="TCP port redirection"                }
        @{ Name="PowerCat";                Pkg="powercat.vm";                    Note="PowerShell netcat replacement"       }
    )

    "C2 Frameworks" = @(
        @{ Name="Sliver  [PRIMARY]";       Pkg="sliver.vm";                      Note="Modern mTLS/HTTP2/QUIC C2"            }
        @{ Name="Covenant";                Pkg="covenant.vm";                    Note=".NET in-memory tasking C2"            }
        @{ Name="Merlin";                  Pkg="merlin.vm";                      Note="HTTP/2 and QUIC transport C2"         }
        @{ Name="C3";                      Pkg="c3.vm";                          Note="Custom communication channels"        }
    )

    "Beacon Object Files" = @(
        @{ Name="Situational Awareness BOF"; Pkg="situational-awareness-bof.vm";   Note="Host recon BOF collection"         }
        @{ Name="TrustedSec Remote Ops";     Pkg="truestedsec-remote-ops-bof.vm";  Note="Offensive BOF toolkit"             }
        @{ Name="Unhook BOF";                Pkg="unhook-bof.vm";                  Note="EDR hook removal"                  }
        @{ Name="Outflank C2 Collection";    Pkg="outflank-c2-tool-collection.vm"; Note="C2 evasion tools"                  }
    )

    "Evasion & Payload Development" = @(
        @{ Name="ConfuserEx";              Pkg="confuserex.vm";                  Note=".NET obfuscator"                      }
        @{ Name="DotNetToJScript";         Pkg="dotnettojscript.vm";             Note=".NET via JScript execution"           }
        @{ Name="GadgetToJScript";         Pkg="gadgettojscript.vm";             Note="Gadget-based JScript loader"          }
        @{ Name="SysWhispers2";            Pkg="syswhispers2.vm";                Note="Direct syscall generator v2"          }
        @{ Name="SysWhispers3";            Pkg="syswhispers3.vm";                Note="Direct syscall generator v3"          }
        @{ Name="Stracciatella";           Pkg="stracciatella.vm";               Note="AMSI/ETW bypass PS runner"            }
        @{ Name="ShellcodeLauncher";       Pkg="shellcode_launcher.vm";          Note="Shellcode execution harness"          }
        @{ Name="UPX";                     Pkg="upx.vm";                         Note="Executable packer"                    }
        @{ Name="EvilClippy";              Pkg="evilclippy.vm";                  Note="Malicious Office document tool"       }
        @{ Name="Invoke-DOSfuscation";     Pkg="invokedosfuscation.vm";          Note="CMD obfuscation framework"            }
        @{ Name="Invoke-Obfuscation";      Pkg="invokeobfuscation.vm";           Note="PowerShell obfuscation"               }
        @{ Name="BadAssMacros";            Pkg="badassmacros.vm";                Note="VBA macro obfuscation"                }
        @{ Name="ResourceHacker";          Pkg="resourcehacker.vm";              Note="PE resource editor"                   }
    )

    "Analysis / Debugging / RE" = @(
        @{ Name="x64dbg";                  Pkg="x64dbg.vm";                      Note="PE debugger (x86/x64)"                }
        @{ Name="WinDbg";                  Pkg="windbg.vm";                      Note="Microsoft kernel/user debugger"       }
        @{ Name="Sysinternals";            Pkg="sysinternals.vm";                Note="ProcMon, ProcExp, AutoRuns, etc."     }
        @{ Name="dnSpyEx";                 Pkg="dnspyex.vm";                     Note=".NET assembly debugger/decompiler"    }
        @{ Name="ILSpy";                   Pkg="ilspy.vm";                       Note=".NET decompiler"                      }
        @{ Name="FakeNet-NG";              Pkg="fakenet-ng.vm";                  Note="Dynamic network simulation"           }
        @{ Name="PE-bear";                 Pkg="pebear.vm";                      Note="PE header analysis"                   }
        @{ Name="PeStudio";                Pkg="pestudio.vm";                    Note="Malware initial triage"               }
        @{ Name="PE-sieve";                Pkg="pesieve.vm";                     Note="Injected code/PE scanner"             }
        @{ Name="Wireshark";               Pkg="wireshark.vm";                   Note="Network packet capture"               }
        @{ Name="HxD";                     Pkg="hxd.vm";                         Note="Hex editor"                           }
        @{ Name="IDA Free";                Pkg="idafree.vm";                     Note="IDA Pro free disassembler"            }
        @{ Name="Ghidra";                  Pkg="ghidra.vm";                      Note="NSA reverse engineering framework"    }
    )

    "Miscellaneous Red Team" = @(
        @{ Name="SharpDump";               Pkg="sharpdump.vm";                   Note="LSASS dump via comsvcs.dll"           }
        @{ Name="Tor Browser";             Pkg="tor-browser.vm";                 Note="Anonymous browsing / OPSEC"           }
    )
}

# ---------------------------------------------------------------------------
# CONSOLE HELPERS
# ---------------------------------------------------------------------------
function Write-Banner {
    Clear-Host
    Write-Host @"

    ================================================================
     BLACKBOX RED - OPERATOR INSTALLER
    ================================================================

  Blackbox Intelligence Group LLC  |  Red Team VM Setup
  Profile: BlackboxRed  |  Base: Mandiant CommandoVM 3.0
"@ -ForegroundColor Red
}

function Write-Divider { Write-Host ("-" * 74) -ForegroundColor DarkGray }
function Write-Step    { param([string]$M); Write-Host "`n[*] $M" -ForegroundColor Cyan }
function Write-OK      { param([string]$M); Write-Host "    [+] $M" -ForegroundColor Green }
function Write-Warn    { param([string]$M); Write-Host "    [!] $M" -ForegroundColor Yellow }
function Write-Fail    { param([string]$M); Write-Host "    [-] $M" -ForegroundColor Red }

function Get-EstimatedDiskGb {
    param([int]$SelectedPackageCount)
    # Rough sizing heuristic for planning purposes in the selection UI.
    $estimate = 24 + ($SelectedPackageCount * 0.55)
    return [math]::Round([math]::Max($estimate, 50), 1)
}

# ---------------------------------------------------------------------------
# INTERACTIVE SELECTION MENU
# $EnabledPkgs = hashtable { CategoryName -> List<string> of enabled pkg IDs }
# ---------------------------------------------------------------------------
function Get-SelectedPackageCount {
    param($EnabledPkgs)
    return ($EnabledPkgs.Values | ForEach-Object { $_ } | Measure-Object).Count
}

function New-BlankEnabledPkgs {
    $ep = [ordered]@{}
    foreach ($cat in $Catalog.Keys) {
        $ep[$cat] = [System.Collections.Generic.List[string]]::new()
    }
    return $ep
}

function Copy-EnabledPkgs {
    param($SourceEnabledPkgs)

    $copy = [ordered]@{}
    foreach ($cat in $Catalog.Keys) {
        $copy[$cat] = [System.Collections.Generic.List[string]]::new()
        if ($null -ne $SourceEnabledPkgs -and $SourceEnabledPkgs.Contains($cat)) {
            foreach ($pkgId in $SourceEnabledPkgs[$cat]) {
                $copy[$cat].Add($pkgId)
            }
        }
    }
    return $copy
}

function New-EnabledPkgs {
    # Default: everything ON
    $ep = [ordered]@{}
    foreach ($cat in $Catalog.Keys) {
        $ep[$cat] = [System.Collections.Generic.List[string]]::new()
        foreach ($pkg in $Catalog[$cat]) { $ep[$cat].Add($pkg.Pkg) }
    }
    return $ep
}

function Set-PresetSelection {
    param(
        [ValidateSet("Professional", "Lean", "Cloud", "Blank")]
        [string]$Preset
    )

    $ep = New-BlankEnabledPkgs

    switch ($Preset) {
        "Professional" {
            return New-EnabledPkgs
        }
        "Blank" {
            return $ep
        }
        "Lean" {
            $enableCategories = @(
                "Utilities & Productivity",
                "Network Reconnaissance",
                "Web & Database",
                "Active Directory & Identity",
                "Privilege Escalation",
                "Credential Access",
                "Lateral Movement & Execution"
            )
        }
        "Cloud" {
            $enableCategories = @(
                "Utilities & Productivity",
                "Development -- Payload Compilation",
                "Network Reconnaissance",
                "Cloud -- Azure / AWS / Entra ID",
                "Active Directory & Identity",
                "Privilege Escalation",
                "Credential Access",
                "Lateral Movement & Execution"
            )
        }
    }

    foreach ($cat in $enableCategories) {
        if (-not $Catalog.Contains($cat)) { continue }
        foreach ($pkg in $Catalog[$cat]) {
            $ep[$cat].Add($pkg.Pkg)
        }
    }
    return $ep
}

function Invoke-QuickStartPreset {
    Write-Banner
    Write-Host "`n  QUICK START" -ForegroundColor White
    Write-Host "  Choose a preset, then fine-tune categories and tools.`n" -ForegroundColor DarkGray
    Write-Divider
    Write-Host "  1. Professional (recommended)  - all capabilities enabled" -ForegroundColor White
    Write-Host "  2. Lean Operator               - streamlined engagement build" -ForegroundColor White
    Write-Host "  3. Cloud Operations            - prioritize cloud and identity tooling" -ForegroundColor White
    Write-Host "  4. Start Blank                 - begin with no packages enabled" -ForegroundColor White
    Write-Divider

    while ($true) {
        $choice = (Read-Host "  Select preset [1-4] (default 1)").Trim()
        if ([string]::IsNullOrWhiteSpace($choice)) { $choice = "1" }

        switch ($choice) {
            "1" { return Set-PresetSelection -Preset Professional }
            "2" { return Set-PresetSelection -Preset Lean }
            "3" { return Set-PresetSelection -Preset Cloud }
            "4" { return Set-PresetSelection -Preset Blank }
            default { Write-Warn "Invalid choice. Please enter 1, 2, 3, or 4." }
        }
    }
}

function Show-SelectionHelp {
    Write-Host @"

  HOW TO USE THIS MENU
  - Enter a category number to toggle that category ON/OFF.
  - Use D<n> to drill into a category and toggle individual tools.
  - Use P to preview selected categories and package counts.
  - Use A or N for global enable/disable, then fine-tune as needed.

"@ -ForegroundColor DarkGray
}

function Show-SelectionPreview {
    param($EnabledPkgs)

    Write-Banner
    Write-Host "`n  SELECTION PREVIEW" -ForegroundColor White
    Write-Divider

    foreach ($cat in $Catalog.Keys) {
        $count = $EnabledPkgs[$cat].Count
        if ($count -gt 0) {
            Write-Host ("  {0,-46} {1,3} package(s)" -f $cat, $count) -ForegroundColor White
        }
    }

    Write-Divider
    $total = Get-SelectedPackageCount -EnabledPkgs $EnabledPkgs
    Write-Host ("  TOTAL SELECTED: {0}" -f $total) -ForegroundColor Cyan
    Write-Host ""
    Read-Host "  Press ENTER to return"
}

function Show-CategoryMenu {
    param($EnabledPkgs)

    Write-Banner
    Write-Host "`n  PACKAGE SELECTION  -  All categories enabled by default" -ForegroundColor White
    Write-Host "  Toggle entire categories or drill in to control individual tools`n" -ForegroundColor DarkGray
    Write-Divider

    $cats = @($Catalog.Keys)
    for ($i = 0; $i -lt $cats.Count; $i++) {
        $cat    = $cats[$i]
        $on     = $EnabledPkgs[$cat].Count
        $total  = $Catalog[$cat].Count
        $state  = if ($on -eq 0)     { "[ OFF ]" } `
                  elseif ($on -eq $total) { "[ ON  ]" } `
                  else                { "[ ---  ]" }
        $color  = if ($on -eq 0)     { "DarkGray" } `
                  elseif ($on -eq $total) { "Green" } `
                  else                { "Yellow" }

        Write-Host ("  {0,2}. " -f ($i+1)) -NoNewline -ForegroundColor DarkGray
        Write-Host ("{0}  " -f $state) -NoNewline -ForegroundColor $color
        Write-Host ("{0,-44}" -f $cat) -NoNewline -ForegroundColor White
        Write-Host ("  {0}/{1} pkgs" -f $on, $total) -ForegroundColor DarkGray
    }

    Write-Divider
        $grand = Get-SelectedPackageCount -EnabledPkgs $EnabledPkgs
    Write-Host ("  Selected: ") -NoNewline -ForegroundColor DarkGray
    Write-Host ("{0} packages total" -f $grand) -ForegroundColor Cyan
    Write-Host @"

  Enter a number to toggle that category ON/OFF
  D<n>   Drill into a category for per-tool control  (e.g. D5)
    A      Enable ALL    N  Disable ALL
    P      Preview       H  Help
    C      Confirm & continue    Q  Quit
"@ -ForegroundColor DarkGray

    return $cats
}

function Show-DrillMenu {
    param([string]$Cat, $EnabledPkgs)

    Write-Banner
    Write-Host "`n  DRILL-DOWN  -  $Cat" -ForegroundColor White
    Write-Divider

    $pkgs = $Catalog[$Cat]
    for ($i = 0; $i -lt $pkgs.Count; $i++) {
        $on    = $EnabledPkgs[$Cat] -contains $pkgs[$i].Pkg
        $state = if ($on) { "[ON ]" } else { "[OFF]" }
        $color = if ($on) { "Green" } else { "DarkGray" }

        Write-Host ("  {0,2}. " -f ($i+1)) -NoNewline -ForegroundColor DarkGray
        Write-Host ("{0}  " -f $state) -NoNewline -ForegroundColor $color
        Write-Host ("{0,-32}" -f $pkgs[$i].Name) -NoNewline -ForegroundColor White
        Write-Host $pkgs[$i].Note -ForegroundColor DarkGray
    }

    Write-Divider
    Write-Host @"

  Enter a number to toggle that tool    A  Enable all    N  Disable all    B  Back
"@ -ForegroundColor DarkGray
}

function Invoke-SelectionConsole {
    param($InitialEnabledPkgs)

    $ep = if ($null -eq $InitialEnabledPkgs) {
        Invoke-QuickStartPreset
    } else {
        Copy-EnabledPkgs -SourceEnabledPkgs $InitialEnabledPkgs
    }

    $inDrill = $false
    $drillCat = ""

    while ($true) {
        if (-not $inDrill) {
            $cats  = Show-CategoryMenu -EnabledPkgs $ep
            $menuInput = (Read-Host "  > ").Trim()

            switch -Regex ($menuInput) {
                '^[Qq]$' { Write-Host "`n  Cancelled.`n" -ForegroundColor Red; exit 0 }

                '^[Cc]$' {
                    $total = Get-SelectedPackageCount -EnabledPkgs $ep
                    if ($total -eq 0) { Write-Warn "No packages selected."; Start-Sleep 2 }
                    else { return $ep }
                }

                '^[Pp]$' { Show-SelectionPreview -EnabledPkgs $ep }
                '^[Hh]$' { Show-SelectionHelp; Start-Sleep -Seconds 2 }

                '^[Aa]$' {
                    foreach ($cat in $Catalog.Keys) {
                        $ep[$cat] = [System.Collections.Generic.List[string]]::new()
                        foreach ($p in $Catalog[$cat]) { $ep[$cat].Add($p.Pkg) }
                    }
                }

                '^[Nn]$' {
                    foreach ($cat in $Catalog.Keys) {
                        $ep[$cat] = [System.Collections.Generic.List[string]]::new()
                    }
                }

                '^[Dd](\d+)$' {
                    $idx = [int]$Matches[1] - 1
                    if ($idx -ge 0 -and $idx -lt $cats.Count) {
                        $drillCat = $cats[$idx]; $inDrill = $true
                    }
                }

                '^\d+$' {
                    $idx = [int]$menuInput - 1
                    if ($idx -ge 0 -and $idx -lt $cats.Count) {
                        $cat = $cats[$idx]
                        if ($ep[$cat].Count -gt 0) {
                            $ep[$cat] = [System.Collections.Generic.List[string]]::new()
                        } else {
                            $ep[$cat] = [System.Collections.Generic.List[string]]::new()
                            foreach ($p in $Catalog[$cat]) { $ep[$cat].Add($p.Pkg) }
                        }
                    }
                }

                default {
                    Write-Warn "Unrecognized command. Use H for help."
                    Start-Sleep -Seconds 1
                }
            }
        }
        else {
            Show-DrillMenu -Cat $drillCat -EnabledPkgs $ep
            $menuInput = (Read-Host "  > ").Trim()
            $pkgs  = $Catalog[$drillCat]

            switch -Regex ($menuInput) {
                '^[Bb]$' { $inDrill = $false }

                '^[Aa]$' {
                    $ep[$drillCat] = [System.Collections.Generic.List[string]]::new()
                    foreach ($p in $pkgs) { $ep[$drillCat].Add($p.Pkg) }
                }

                '^[Nn]$' {
                    $ep[$drillCat] = [System.Collections.Generic.List[string]]::new()
                }

                '^\d+$' {
                    $idx = [int]$menuInput - 1
                    if ($idx -ge 0 -and $idx -lt $pkgs.Count) {
                        $id = $pkgs[$idx].Pkg
                        if ($ep[$drillCat] -contains $id) { $ep[$drillCat].Remove($id) | Out-Null }
                        else { $ep[$drillCat].Add($id) }
                    }
                }

                default {
                    Write-Warn "Unrecognized command. Use a number, A, N, or B."
                    Start-Sleep -Seconds 1
                }
            }
        }
    }
}

function Invoke-SelectionGui {
    param($InitialEnabledPkgs)

    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing

    $ep = Copy-EnabledPkgs -SourceEnabledPkgs $InitialEnabledPkgs

    $form = New-Object System.Windows.Forms.Form
    $form.Text = "BlackboxRed Installer - Package Designer"
    $form.StartPosition = "CenterScreen"
    $form.Size = New-Object System.Drawing.Size(1180, 760)
    $form.MinimumSize = New-Object System.Drawing.Size(1024, 700)

    $themeBg = [System.Drawing.Color]::FromArgb(18, 20, 24)
    $themePanel = [System.Drawing.Color]::FromArgb(28, 32, 38)
    $themeInput = [System.Drawing.Color]::FromArgb(21, 24, 29)
    $themeFg = [System.Drawing.Color]::FromArgb(230, 234, 240)
    $themeMuted = [System.Drawing.Color]::FromArgb(150, 160, 172)
    $themeAccent = [System.Drawing.Color]::FromArgb(194, 38, 51)
    $themeAccentStrong = [System.Drawing.Color]::FromArgb(230, 65, 80)

    $form.BackColor = $themeBg
    $form.ForeColor = $themeFg

    $header = New-Object System.Windows.Forms.Label
    $header.Location = New-Object System.Drawing.Point(16, 14)
    $header.AutoSize = $true
    $header.Font = New-Object System.Drawing.Font("Segoe UI", 13, [System.Drawing.FontStyle]::Bold)
    $header.Text = "BlackboxRed Package Designer"
    $header.ForeColor = $themeAccentStrong

    $subHeader = New-Object System.Windows.Forms.Label
    $subHeader.Location = New-Object System.Drawing.Point(18, 42)
    $subHeader.Size = New-Object System.Drawing.Size(1100, 32)
    $subHeader.Font = New-Object System.Drawing.Font("Segoe UI", 9)
    $subHeader.Text = "Choose a category on the left, then check/uncheck packages on the right. Use presets in console first, then fine tune here."
    $subHeader.ForeColor = $themeMuted

    $categoryLabel = New-Object System.Windows.Forms.Label
    $categoryLabel.Location = New-Object System.Drawing.Point(18, 86)
    $categoryLabel.AutoSize = $true
    $categoryLabel.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
    $categoryLabel.Text = "Categories"
    $categoryLabel.ForeColor = $themeFg

    $categoryList = New-Object System.Windows.Forms.ListBox
    $categoryList.Location = New-Object System.Drawing.Point(18, 110)
    $categoryList.Size = New-Object System.Drawing.Size(330, 490)
    $categoryList.Font = New-Object System.Drawing.Font("Segoe UI", 9)
    $categoryList.BackColor = $themeInput
    $categoryList.ForeColor = $themeFg
    $categoryList.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle

    $packageLabel = New-Object System.Windows.Forms.Label
    $packageLabel.Location = New-Object System.Drawing.Point(366, 86)
    $packageLabel.AutoSize = $true
    $packageLabel.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
    $packageLabel.Text = "Packages"
    $packageLabel.ForeColor = $themeFg

    $searchBox = New-Object System.Windows.Forms.TextBox
    $searchBox.Location = New-Object System.Drawing.Point(430, 84)
    $searchBox.Size = New-Object System.Drawing.Size(320, 23)
    $searchBox.Font = New-Object System.Drawing.Font("Segoe UI", 9)
    $searchBox.BackColor = $themeInput
    $searchBox.ForeColor = $themeFg
    $searchBox.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle

    $searchLabel = New-Object System.Windows.Forms.Label
    $searchLabel.Location = New-Object System.Drawing.Point(756, 87)
    $searchLabel.AutoSize = $true
    $searchLabel.Font = New-Object System.Drawing.Font("Segoe UI", 8)
    $searchLabel.Text = "Filter current category"
    $searchLabel.ForeColor = $themeMuted

    $packageList = New-Object System.Windows.Forms.CheckedListBox
    $packageList.Location = New-Object System.Drawing.Point(366, 110)
    $packageList.Size = New-Object System.Drawing.Size(785, 490)
    $packageList.CheckOnClick = $true
    $packageList.Font = New-Object System.Drawing.Font("Segoe UI", 9)
    $packageList.BackColor = $themeInput
    $packageList.ForeColor = $themeFg
    $packageList.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle

    $statusLabel = New-Object System.Windows.Forms.Label
    $statusLabel.Location = New-Object System.Drawing.Point(18, 614)
    $statusLabel.Size = New-Object System.Drawing.Size(770, 22)
    $statusLabel.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
    $statusLabel.ForeColor = $themeFg

    $estimateLabel = New-Object System.Windows.Forms.Label
    $estimateLabel.Location = New-Object System.Drawing.Point(18, 638)
    $estimateLabel.Size = New-Object System.Drawing.Size(770, 20)
    $estimateLabel.Font = New-Object System.Drawing.Font("Segoe UI", 9)
    $estimateLabel.ForeColor = $themeMuted

    $btnExport = New-Object System.Windows.Forms.Button
    $btnExport.Location = New-Object System.Drawing.Point(806, 570)
    $btnExport.Size = New-Object System.Drawing.Size(112, 32)
    $btnExport.Text = "Export Selection Preset"

    $btnImport = New-Object System.Windows.Forms.Button
    $btnImport.Location = New-Object System.Drawing.Point(924, 570)
    $btnImport.Size = New-Object System.Drawing.Size(112, 32)
    $btnImport.Text = "Import Preset"

    $btnEnableCat = New-Object System.Windows.Forms.Button
    $btnEnableCat.Location = New-Object System.Drawing.Point(806, 610)
    $btnEnableCat.Size = New-Object System.Drawing.Size(112, 32)
    $btnEnableCat.Text = "Enable Category"

    $btnDisableCat = New-Object System.Windows.Forms.Button
    $btnDisableCat.Location = New-Object System.Drawing.Point(924, 610)
    $btnDisableCat.Size = New-Object System.Drawing.Size(112, 32)
    $btnDisableCat.Text = "Disable Category"

    $btnEnableAll = New-Object System.Windows.Forms.Button
    $btnEnableAll.Location = New-Object System.Drawing.Point(806, 650)
    $btnEnableAll.Size = New-Object System.Drawing.Size(112, 32)
    $btnEnableAll.Text = "Enable All"

    $btnDisableAll = New-Object System.Windows.Forms.Button
    $btnDisableAll.Location = New-Object System.Drawing.Point(924, 650)
    $btnDisableAll.Size = New-Object System.Drawing.Size(112, 32)
    $btnDisableAll.Text = "Disable All"

    $btnCancel = New-Object System.Windows.Forms.Button
    $btnCancel.Location = New-Object System.Drawing.Point(1042, 650)
    $btnCancel.Size = New-Object System.Drawing.Size(109, 32)
    $btnCancel.Text = "Cancel"

    $btnContinue = New-Object System.Windows.Forms.Button
    $btnContinue.Location = New-Object System.Drawing.Point(1042, 610)
    $btnContinue.Size = New-Object System.Drawing.Size(109, 32)
    $btnContinue.Text = "Continue"

    $buttonList = @($btnExport, $btnImport, $btnEnableCat, $btnDisableCat, $btnEnableAll, $btnDisableAll, $btnContinue, $btnCancel)
    foreach ($button in $buttonList) {
        $button.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
        $button.FlatAppearance.BorderSize = 1
        $button.FlatAppearance.BorderColor = [System.Drawing.Color]::FromArgb(56, 62, 74)
        $button.BackColor = $themePanel
        $button.ForeColor = $themeFg
        $button.Font = New-Object System.Drawing.Font("Segoe UI", 9)
    }

    $btnContinue.BackColor = $themeAccent
    $btnContinue.FlatAppearance.BorderColor = $themeAccentStrong
    $btnContinue.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)

    $form.Controls.AddRange(@(
        $header,
        $subHeader,
        $categoryLabel,
        $categoryList,
        $packageLabel,
        $searchBox,
        $searchLabel,
        $packageList,
        $statusLabel,
        $estimateLabel,
        $btnExport,
        $btnImport,
        $btnEnableCat,
        $btnDisableCat,
        $btnEnableAll,
        $btnDisableAll,
        $btnContinue,
        $btnCancel
    ))

    $script:GuiCategoryNames = @($Catalog.Keys)
    $script:GuiCurrentCategory = $script:GuiCategoryNames[0]
    $script:GuiVisibleMap = @()
    $script:GuiUpdatingChecks = $false

    function Refresh-GuiTotals {
        $selectedCount = Get-SelectedPackageCount -EnabledPkgs $ep
        $totalAvailable = ($Catalog.Values | ForEach-Object { $_ } | Measure-Object).Count
        $statusLabel.Text = "Selected packages: $selectedCount / $totalAvailable"
        $estimateGb = Get-EstimatedDiskGb -SelectedPackageCount $selectedCount
        $estimateLabel.Text = "Estimated required disk footprint: ~${estimateGb} GB"
    }

    function Get-SelectionExportObject {
        $categoryMap = [ordered]@{}
        foreach ($cat in $Catalog.Keys) {
            $selectedIds = @($ep[$cat])
            if ($selectedIds.Count -eq 0) { continue }
            $categoryMap[$cat] = $selectedIds
        }

        return [ordered]@{
            name = "BlackboxRed Custom Preset"
            createdOnUtc = [DateTime]::UtcNow.ToString("o")
            selectedPackageCount = (Get-SelectedPackageCount -EnabledPkgs $ep)
            estimatedDiskGb = (Get-EstimatedDiskGb -SelectedPackageCount (Get-SelectedPackageCount -EnabledPkgs $ep))
            categories = $categoryMap
        }
    }

    function Import-SelectionPreset {
        param([string]$PresetPath)

        $jsonRaw = Get-Content -Path $PresetPath -Raw
        $presetObj = $jsonRaw | ConvertFrom-Json

        if ($null -eq $presetObj -or $null -eq $presetObj.categories) {
            throw "Invalid preset file: missing categories object."
        }

        $newSelection = New-BlankEnabledPkgs

        foreach ($cat in $Catalog.Keys) {
            if ($null -eq $presetObj.categories.$cat) { continue }

            $validPkgIds = @($Catalog[$cat] | ForEach-Object { $_.Pkg })
            $importedPkgIds = @($presetObj.categories.$cat)

            foreach ($pkgId in $importedPkgIds) {
                if ($validPkgIds -contains $pkgId) {
                    $newSelection[$cat].Add([string]$pkgId)
                }
            }
        }

        return $newSelection
    }

    function Refresh-GuiCategoryList {
        $categoryList.BeginUpdate()
        $selectedIndex = $categoryList.SelectedIndex
        $categoryList.Items.Clear()

        foreach ($cat in $script:GuiCategoryNames) {
            $on = $ep[$cat].Count
            $total = $Catalog[$cat].Count
            $categoryList.Items.Add("$cat  ($on/$total)") | Out-Null
        }

        if ($selectedIndex -lt 0) { $selectedIndex = 0 }
        if ($selectedIndex -ge $categoryList.Items.Count) { $selectedIndex = $categoryList.Items.Count - 1 }
        if ($selectedIndex -ge 0) { $categoryList.SelectedIndex = $selectedIndex }
        $categoryList.EndUpdate()
    }

    function Refresh-GuiPackageList {
        $script:GuiUpdatingChecks = $true
        $packageList.BeginUpdate()
        $packageList.Items.Clear()
        $script:GuiVisibleMap = @()

        $filter = $searchBox.Text.Trim().ToLowerInvariant()
        $catPkgs = $Catalog[$script:GuiCurrentCategory]

        for ($idx = 0; $idx -lt $catPkgs.Count; $idx++) {
            $pkg = $catPkgs[$idx]
            $display = "{0}  |  {1}" -f $pkg.Name, $pkg.Note

            if ($filter -ne "") {
                $hay = ("{0} {1} {2}" -f $pkg.Name, $pkg.Pkg, $pkg.Note).ToLowerInvariant()
                if (-not $hay.Contains($filter)) { continue }
            }

            $newIndex = $packageList.Items.Add($display)
            $script:GuiVisibleMap += $idx
            $isChecked = $ep[$script:GuiCurrentCategory] -contains $pkg.Pkg
            $packageList.SetItemChecked($newIndex, $isChecked)
        }

        $packageList.EndUpdate()
        $script:GuiUpdatingChecks = $false
        Refresh-GuiTotals
    }

    Refresh-GuiCategoryList
    $categoryList.SelectedIndex = 0

    $categoryList.Add_SelectedIndexChanged({
        if ($categoryList.SelectedIndex -lt 0) { return }
        $script:GuiCurrentCategory = $script:GuiCategoryNames[$categoryList.SelectedIndex]
        Refresh-GuiPackageList
    })

    $searchBox.Add_TextChanged({ Refresh-GuiPackageList })

    $packageList.Add_ItemCheck({
        if ($script:GuiUpdatingChecks) { return }
        if ($e.Index -lt 0 -or $e.Index -ge $script:GuiVisibleMap.Count) { return }

        $catPkgIdx = $script:GuiVisibleMap[$e.Index]
        $pkgId = $Catalog[$script:GuiCurrentCategory][$catPkgIdx].Pkg

        if ($e.NewValue -eq [System.Windows.Forms.CheckState]::Checked) {
            if (-not ($ep[$script:GuiCurrentCategory] -contains $pkgId)) {
                $ep[$script:GuiCurrentCategory].Add($pkgId)
            }
        } else {
            [void]$ep[$script:GuiCurrentCategory].Remove($pkgId)
        }

        Refresh-GuiCategoryList
        Refresh-GuiTotals
    })

    $btnEnableCat.Add_Click({
        foreach ($pkg in $Catalog[$script:GuiCurrentCategory]) {
            if (-not ($ep[$script:GuiCurrentCategory] -contains $pkg.Pkg)) {
                $ep[$script:GuiCurrentCategory].Add($pkg.Pkg)
            }
        }
        Refresh-GuiCategoryList
        Refresh-GuiPackageList
    })

    $btnDisableCat.Add_Click({
        $ep[$script:GuiCurrentCategory] = [System.Collections.Generic.List[string]]::new()
        Refresh-GuiCategoryList
        Refresh-GuiPackageList
    })

    $btnEnableAll.Add_Click({
        foreach ($cat in $Catalog.Keys) {
            $ep[$cat] = [System.Collections.Generic.List[string]]::new()
            foreach ($pkg in $Catalog[$cat]) { $ep[$cat].Add($pkg.Pkg) }
        }
        Refresh-GuiCategoryList
        Refresh-GuiPackageList
    })

    $btnDisableAll.Add_Click({
        foreach ($cat in $Catalog.Keys) {
            $ep[$cat] = [System.Collections.Generic.List[string]]::new()
        }
        Refresh-GuiCategoryList
        Refresh-GuiPackageList
    })

    $btnExport.Add_Click({
        $saveDialog = New-Object System.Windows.Forms.SaveFileDialog
        $saveDialog.Title = "Export BlackboxRed Selection Preset"
        $saveDialog.Filter = "JSON files (*.json)|*.json"
        $saveDialog.InitialDirectory = (Join-Path $PSScriptRoot "Profiles")
        $saveDialog.FileName = "BlackboxRed-SelectionPreset.json"

        if ($saveDialog.ShowDialog() -ne [System.Windows.Forms.DialogResult]::OK) { return }

        $exportObj = Get-SelectionExportObject
        $exportJson = $exportObj | ConvertTo-Json -Depth 8
        Set-Content -Path $saveDialog.FileName -Value $exportJson -Encoding UTF8

        [System.Windows.Forms.MessageBox]::Show(
            "Selection preset exported to:`n$($saveDialog.FileName)",
            "BlackboxRed",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Information
        ) | Out-Null
    })

    $btnImport.Add_Click({
        $openDialog = New-Object System.Windows.Forms.OpenFileDialog
        $openDialog.Title = "Import BlackboxRed Selection Preset"
        $openDialog.Filter = "JSON files (*.json)|*.json"
        $openDialog.InitialDirectory = (Join-Path $PSScriptRoot "Profiles")

        if ($openDialog.ShowDialog() -ne [System.Windows.Forms.DialogResult]::OK) { return }

        try {
            $importedSelection = Import-SelectionPreset -PresetPath $openDialog.FileName
            $ep = Copy-EnabledPkgs -SourceEnabledPkgs $importedSelection
            Refresh-GuiCategoryList
            Refresh-GuiPackageList

            $importCount = Get-SelectedPackageCount -EnabledPkgs $ep
            [System.Windows.Forms.MessageBox]::Show(
                "Preset imported successfully.`nSelected packages: $importCount",
                "BlackboxRed",
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Information
            ) | Out-Null
        }
        catch {
            [System.Windows.Forms.MessageBox]::Show(
                "Failed to import preset:`n$($_.Exception.Message)",
                "BlackboxRed",
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Error
            ) | Out-Null
        }
    })

    $btnCancel.Add_Click({
        $form.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
        $form.Close()
    })

    $btnContinue.Add_Click({
        $selectedCount = Get-SelectedPackageCount -EnabledPkgs $ep
        if ($selectedCount -eq 0) {
            [System.Windows.Forms.MessageBox]::Show(
                "No packages selected. Please select at least one package.",
                "BlackboxRed",
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Warning
            ) | Out-Null
            return
        }

        $form.DialogResult = [System.Windows.Forms.DialogResult]::OK
        $form.Close()
    })

    Refresh-GuiTotals
    Refresh-GuiPackageList

    $dialogResult = $form.ShowDialog()
    if ($dialogResult -ne [System.Windows.Forms.DialogResult]::OK) {
        Write-Host "`n  Cancelled.`n" -ForegroundColor Red
        exit 0
    }

    return $ep
}

function Invoke-SelectionMenu {
    $presetSelection = Invoke-QuickStartPreset

    if ($UseGui.IsPresent) {
        try {
            return Invoke-SelectionGui -InitialEnabledPkgs $presetSelection
        }
        catch {
            Write-Warn "GUI mode failed: $($_.Exception.Message)"
            Write-Warn "Falling back to console selector."
            Start-Sleep -Seconds 2
            return Invoke-SelectionConsole -InitialEnabledPkgs $presetSelection
        }
    }

    return Invoke-SelectionConsole -InitialEnabledPkgs $presetSelection
}

# ---------------------------------------------------------------------------
# GENERATE PROFILE XML FROM SELECTION
# ---------------------------------------------------------------------------
function New-ProfileXml {
    param($EnabledPkgs)

    Write-Step "Generating BlackboxRed-Custom.xml..."

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm"
    $total     = ($EnabledPkgs.Values | ForEach-Object { $_ } | Measure-Object).Count

    $sb = [System.Text.StringBuilder]::new()
    [void]$sb.AppendLine('<?xml version="1.0" encoding="utf-8"?>')
    [void]$sb.AppendLine("<!-- Blackbox Intelligence Group LLC -- Red Team VM Profile -->")
    [void]$sb.AppendLine("<!-- Generated: $timestamp  |  Packages selected: $total -->")
    [void]$sb.AppendLine('<config>')
    [void]$sb.AppendLine('  <envs>')
    [void]$sb.AppendLine('    <env name="MIN_DISK_SPACE" value="90" />')
    [void]$sb.AppendLine('    <env name="VM_COMMON_DIR" value="%ProgramData%\_VM" />')
    [void]$sb.AppendLine('    <env name="TOOL_LIST_DIR" value="%ProgramData%\Microsoft\Windows\Start Menu\Programs\Tools" />')
    [void]$sb.AppendLine('    <env name="TOOL_LIST_SHORTCUT" value="%UserProfile%\Desktop\Tools.lnk" />')
    [void]$sb.AppendLine('    <env name="RAW_TOOLS_DIR" value="%SystemDrive%\Tools" />')
    [void]$sb.AppendLine('  </envs>')
    [void]$sb.AppendLine('  <packages>')
    [void]$sb.AppendLine()

    foreach ($cat in $Catalog.Keys) {
        $selected = $EnabledPkgs[$cat]
        if ($selected.Count -eq 0) { continue }

        [void]$sb.AppendLine("    <!-- $cat -->")
        foreach ($pkg in $Catalog[$cat]) {
            if ($selected -contains $pkg.Pkg) {
                [void]$sb.AppendLine("    <package name=`"$($pkg.Pkg)`" />")
            }
        }
        [void]$sb.AppendLine()
    }

    [void]$sb.AppendLine('  </packages>')
    [void]$sb.AppendLine('</config>')

    $dir = Split-Path $GeneratedProfile
    if (-not (Test-Path $dir)) { New-Item $dir -ItemType Directory -Force | Out-Null }
    $sb.ToString() | Set-Content -Path $GeneratedProfile -Encoding UTF8

    Write-OK "Saved: $GeneratedProfile  ($total packages)"
}

# ---------------------------------------------------------------------------
# PRE-INSTALL CHECKS
# ---------------------------------------------------------------------------
function Invoke-PreChecks {
    Write-Step "Running pre-install validation..."
    $ok = $true

    $p = [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
    if ($p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) { Write-OK "Running as Administrator" }
    else { Write-Fail "Not running as Administrator"; $ok = $false }

    if ((Get-ExecutionPolicy) -eq "Unrestricted") { Write-OK "Execution policy: Unrestricted" }
    else { Write-Warn "Run: Set-ExecutionPolicy Unrestricted -Force"; $ok = $false }

    try {
        $def = Get-MpPreference -ErrorAction SilentlyContinue
        if ($def.DisableRealtimeMonitoring) { Write-OK "Defender real-time protection: Disabled" }
        else { Write-Warn "Defender real-time protection ENABLED - disable via Group Policy first"; $ok = $false }
    } catch { Write-Warn "Could not query Defender status - verify manually" }

    $build     = [System.Environment]::OSVersion.Version.Build
    $supported = @(19045, 22621, 22631, 26100)
    if ($build -in $supported) { Write-OK "OS build $build is supported" }
    else { Write-Warn "OS build $build not in tested list - continuing at your risk" }

    $freeGB = [math]::Round((Get-PSDrive (Get-Location).Drive.Name).Free / 1GB, 1)
    if ($freeGB -ge 90) { Write-OK "Free disk space: ${freeGB} GB" }
    else { Write-Warn "Free disk: ${freeGB} GB - 90+ GB recommended"; $ok = $false }

    return $ok
}

# ---------------------------------------------------------------------------
# ENSURE GIT
# ---------------------------------------------------------------------------
function Install-GitIfMissing {
    if (Get-Command git -ErrorAction SilentlyContinue) { return }
    Write-Step "Git not found - attempting auto-install..."
    if (Get-Command winget -ErrorAction SilentlyContinue) {
        winget install --id Git.Git -e --source winget --accept-package-agreements --accept-source-agreements
    } else {
        if (-not (Get-Command choco -ErrorAction SilentlyContinue)) {
            [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
            Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
            $env:PATH += ";${env:ProgramData}\chocolatey\bin"
        }
        choco install git -y --no-progress
    }
    $env:PATH = [System.Environment]::GetEnvironmentVariable("PATH","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("PATH","User")
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
        throw "Git install failed. Install manually from https://git-scm.com and re-run."
    }
    Write-OK "Git installed"
}

# ---------------------------------------------------------------------------
# CLONE REPO
# ---------------------------------------------------------------------------
function Invoke-PrepareInstallerSource {
    Write-Step "Preparing installer source..."

    $profilesDir = Join-Path $InstallerRoot "Profiles"
    $imagesDir = Join-Path $InstallerRoot "Images"

    if ((Test-Path $InstallScript) -and (Test-Path $profilesDir) -and (Test-Path $imagesDir)) {
        Write-OK "Using local installer source: $InstallerRoot"
        return
    }

    if ($SkipClone.IsPresent) {
        throw "Installer source is incomplete at $InstallerRoot and -SkipClone was specified."
    }

    if ([string]::IsNullOrWhiteSpace($InstallerRepoUrl)) {
        throw "Installer source not found at $InstallerRoot. Provide -InstallerRepoUrl to clone a compatible source."
    }

    if (Test-Path $InstallerRoot) {
        Write-Warn "InstallerRoot exists but is incomplete: $InstallerRoot"
        $c = Read-Host "    Overwrite and clone fresh? (y/N)"
        if ($c -notin @('y','Y')) { throw "Aborted by user." }
        Remove-Item $InstallerRoot -Recurse -Force
    }

    git clone $InstallerRepoUrl $InstallerRoot
    if ($LASTEXITCODE -ne 0) { throw "git clone failed (exit $LASTEXITCODE)" }

    if (-not (Test-Path $InstallScript)) {
        throw "Cloned source does not contain install.ps1 at expected path: $InstallScript"
    }

    Write-OK "Installer source ready: $InstallerRoot"
}

# ---------------------------------------------------------------------------
# INJECT PROFILE
# ---------------------------------------------------------------------------
function Invoke-InjectProfile {
    Write-Step "Injecting BlackboxRed-Custom profile..."
    if (-not (Test-Path $GeneratedProfile)) { throw "Generated profile missing: $GeneratedProfile" }
    Copy-Item -Path $GeneratedProfile -Destination $ProfileDest -Force
    Write-OK "Profile injected: $ProfileDest"
}

# ---------------------------------------------------------------------------
# INJECT WALLPAPER BRANDING
# ---------------------------------------------------------------------------
function Invoke-InjectWallpaper {
    Write-Step "Injecting Blackbox RED wallpaper branding..."

    if (-not (Test-Path $WallpaperSource)) {
        throw "Wallpaper source file not found: $WallpaperSource"
    }

    $imagesDir = Join-Path $InstallerRoot "Images"
    if (-not (Test-Path $imagesDir)) {
        throw "CommandoVM Images directory not found: $imagesDir"
    }

    $mainWallpaperTarget = Join-Path $imagesDir "background.png"
    $victimWallpaperTarget = Join-Path $imagesDir "background-victim.png"

    Copy-Item -Path $WallpaperSource -Destination $mainWallpaperTarget -Force
    Copy-Item -Path $WallpaperSource -Destination $victimWallpaperTarget -Force

    Write-OK "Wallpaper set: $mainWallpaperTarget"
    Write-OK "Wallpaper set: $victimWallpaperTarget"
}

# ---------------------------------------------------------------------------
# UNBLOCK FILES
# ---------------------------------------------------------------------------
function Invoke-UnblockFiles {
    Write-Step "Unblocking repository files..."
    Get-ChildItem -Path $InstallerRoot -Recurse | Unblock-File
    Write-OK "Files unblocked"
}

# ---------------------------------------------------------------------------
# LAUNCH COMMANDO INSTALLER
# ---------------------------------------------------------------------------
function Invoke-CommandoInstaller {
    Write-Step "Launching CommandoVM installer..."
    if (-not (Test-Path $InstallScript)) { throw "install.ps1 not found: $InstallScript" }

    $installArgs = @()
    if ($SkipChecks.IsPresent) { $installArgs += "-skipChecks" }
    if ($NoPassword.IsPresent) { $installArgs += "-noPassword" }

    if ($CLI.IsPresent) {
        $installArgs += "-cli"
        $installArgs += "-customProfile `"$ProfileDest`""
        if ($Password -ne "") { $installArgs += "-password `"$Password`"" }
        Write-OK "Mode: CLI headless"
    } else {
        Write-OK "Mode: GUI - select 'BlackboxRed-Custom' from the Profile dropdown"
    }

    $argStr = $installArgs -join " "
    Write-Host "`n    powershell.exe -NoProfile -ExecutionPolicy Unrestricted -File install.ps1 $argStr`n" -ForegroundColor DarkGray
    Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Unrestricted -File `"$InstallScript`" $argStr" -Verb RunAs -Wait
}

# ===========================================================================
# MAIN FLOW
# ===========================================================================
Set-ItemProperty -Path 'HKCU:\Console' -Name 'QuickEdit'  -Value 0 -ErrorAction SilentlyContinue
Set-ItemProperty -Path 'HKCU:\Console' -Name 'InsertMode' -Value 0 -ErrorAction SilentlyContinue

Write-Banner

# Step 1 - Pre-checks
if (-not $SkipChecks.IsPresent) {
    $ok = Invoke-PreChecks
    if (-not $ok) {
        Write-Host "`n[!] One or more checks failed." -ForegroundColor Yellow
        $c = Read-Host "    Continue anyway? (y/N)"
        if ($c -notin @('y','Y')) { Write-Host "`nCancelled.`n" -ForegroundColor Red; exit 1 }
    }
} else {
    Write-Warn "Pre-install checks skipped (-SkipChecks)"
}

# Step 2 - Interactive package selection
if ($UseGui.IsPresent) {
    Write-Host "`n  Press ENTER to launch the BlackboxRed package designer..." -ForegroundColor DarkGray
} else {
    Write-Host "`n  Press ENTER to open the package selection menu..." -ForegroundColor DarkGray
}
$null = Read-Host
$selectedPkgs = Invoke-SelectionMenu

# Step 3 - Confirm summary before proceeding
Write-Banner
Write-Step "Install summary"
Write-Divider
foreach ($cat in $Catalog.Keys) {
    $n = $selectedPkgs[$cat].Count
    if ($n -gt 0) {
        $catTotal = $Catalog[$cat].Count
        $pct = [math]::Round(($n / $catTotal) * 100)
        Write-Host ("  {0,-38} {1,3}/{2,-3} ({3,3}%)" -f $cat, $n, $catTotal, $pct) -ForegroundColor White
    }
}
Write-Divider
$grand = ($selectedPkgs.Values | ForEach-Object { $_ } | Measure-Object).Count
$estimateGb = Get-EstimatedDiskGb -SelectedPackageCount $grand
Write-Host ("  Total packages to install: ") -NoNewline -ForegroundColor DarkGray
Write-Host $grand -ForegroundColor Cyan
Write-Host ("  Estimated disk footprint : ") -NoNewline -ForegroundColor DarkGray
Write-Host ("~{0} GB" -f $estimateGb) -ForegroundColor Cyan
Write-Host ""

$confirm = Read-Host "  Proceed with installation? (y/N)"
if ($confirm -notin @('y','Y')) { Write-Host "`nCancelled.`n" -ForegroundColor Red; exit 0 }

# Step 4 - Build profile, clone, inject, launch
try {
    New-ProfileXml    -EnabledPkgs $selectedPkgs
    Install-GitIfMissing

    Invoke-PrepareInstallerSource

    Invoke-InjectProfile
    Invoke-InjectWallpaper
    Invoke-UnblockFiles
    Invoke-CommandoInstaller

    Write-Host "`n[+] Setup complete. Watch the Boxstarter window for progress." -ForegroundColor Green
    Write-Host "    Expect multiple automatic reboots - installation will resume after each one.`n" -ForegroundColor Green

} catch {
    Write-Host "`n[!] FATAL: $($_.Exception.Message)`n" -ForegroundColor Red
    exit 1
}
