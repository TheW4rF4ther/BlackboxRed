<#
.SYNOPSIS
    Blackbox Intelligence Group LLC — CommandoVM Red Team Setup Script
    Interactive category/package selector + one-click installer launcher.

.DESCRIPTION
    This script:
      1. Validates pre-install requirements
      2. Presents an interactive category/package selection menu
      3. Generates a filtered BlackboxRed-Custom.xml based on your selections
      4. Clones the Mandiant commando-vm repository
      5. Injects the generated profile and launches the CommandoVM installer

.PARAMETER SkipClone
    Reuse an existing commando-vm clone instead of cloning fresh.

.PARAMETER NoPassword
    Pass when the Windows account has no password set.

.PARAMETER SkipChecks
    Bypass pre-install validation (NOT recommended).

.PARAMETER CLI
    Launch CommandoVM installer in headless CLI mode (no GUI).

.PARAMETER Password
    Windows account password for Boxstarter reboot-resilience (CLI mode).

.EXAMPLE
    .\setup.ps1
    .\setup.ps1 -CLI -Password "YourPassword"
    .\setup.ps1 -SkipClone -SkipChecks
#>

[CmdletBinding()]
param (
    [switch]$SkipClone,
    [switch]$NoPassword,
    [switch]$SkipChecks,
    [switch]$CLI,
    [string]$Password = ""
)

#Requires -RunAsAdministrator

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# ---------------------------------------------------------------------------
# CONFIGURATION
# ---------------------------------------------------------------------------
$RepoUrl          = "https://github.com/mandiant/commando-vm.git"
$RepoDestination  = Join-Path $PSScriptRoot "commando-vm"
$GeneratedProfile = Join-Path $PSScriptRoot "Profiles\BlackboxRed-Custom.xml"
$ProfileDest      = Join-Path $RepoDestination "Profiles\BlackboxRed-Custom.xml"
$InstallScript    = Join-Path $RepoDestination "install.ps1"

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

  ██████╗ ██╗      █████╗  ██████╗██╗  ██╗██████╗  ██████╗ ██╗  ██╗
  ██╔══██╗██║     ██╔══██╗██╔════╝██║ ██╔╝██╔══██╗██╔═══██╗╚██╗██╔╝
  ██████╔╝██║     ███████║██║     █████╔╝ ██████╔╝██║   ██║ ╚███╔╝
  ██╔══██╗██║     ██╔══██║██║     ██╔═██╗ ██╔══██╗██║   ██║ ██╔██╗
  ██████╔╝███████╗██║  ██║╚██████╗██║  ██╗██████╔╝╚██████╔╝██╔╝ ██╗
  ╚═════╝ ╚══════╝╚═╝  ╚═╝ ╚═════╝╚═╝  ╚═╝╚═════╝  ╚═════╝ ╚═╝  ╚═╝

  Blackbox Intelligence Group LLC  |  Red Team VM Setup
  Profile: BlackboxRed  |  Base: Mandiant CommandoVM 3.0
"@ -ForegroundColor Red
}

function Write-Divider { Write-Host ("─" * 74) -ForegroundColor DarkGray }
function Write-Step    { param([string]$M); Write-Host "`n[*] $M" -ForegroundColor Cyan }
function Write-OK      { param([string]$M); Write-Host "    [+] $M" -ForegroundColor Green }
function Write-Warn    { param([string]$M); Write-Host "    [!] $M" -ForegroundColor Yellow }
function Write-Fail    { param([string]$M); Write-Host "    [-] $M" -ForegroundColor Red }

# ---------------------------------------------------------------------------
# INTERACTIVE SELECTION MENU
# $EnabledPkgs = hashtable { CategoryName -> List<string> of enabled pkg IDs }
# ---------------------------------------------------------------------------
function New-EnabledPkgs {
    # Default: everything ON
    $ep = [ordered]@{}
    foreach ($cat in $Catalog.Keys) {
        $ep[$cat] = [System.Collections.Generic.List[string]]::new()
        foreach ($pkg in $Catalog[$cat]) { $ep[$cat].Add($pkg.Pkg) }
    }
    return $ep
}

function Show-CategoryMenu {
    param($EnabledPkgs)

    Write-Banner
    Write-Host "`n  PACKAGE SELECTION  —  All categories enabled by default" -ForegroundColor White
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
    $grand = ($EnabledPkgs.Values | ForEach-Object { $_ } | Measure-Object).Count
    Write-Host ("  Selected: ") -NoNewline -ForegroundColor DarkGray
    Write-Host ("{0} packages total" -f $grand) -ForegroundColor Cyan
    Write-Host @"

  Enter a number to toggle that category ON/OFF
  D<n>   Drill into a category for per-tool control  (e.g. D5)
  A      Enable ALL    N  Disable ALL    C  Confirm & continue    Q  Quit
"@ -ForegroundColor DarkGray

    return $cats
}

function Show-DrillMenu {
    param([string]$Cat, $EnabledPkgs)

    Write-Banner
    Write-Host "`n  DRILL-DOWN  —  $Cat" -ForegroundColor White
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

function Invoke-SelectionMenu {
    $ep      = New-EnabledPkgs
    $inDrill = $false
    $drillCat = ""

    while ($true) {
        if (-not $inDrill) {
            $cats  = Show-CategoryMenu -EnabledPkgs $ep
            $input = (Read-Host "  > ").Trim()

            switch -Regex ($input) {
                '^[Qq]$' { Write-Host "`n  Cancelled.`n" -ForegroundColor Red; exit 0 }

                '^[Cc]$' {
                    $total = ($ep.Values | ForEach-Object { $_ } | Measure-Object).Count
                    if ($total -eq 0) { Write-Warn "No packages selected."; Start-Sleep 2 }
                    else { return $ep }
                }

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
                    $idx = [int]$input - 1
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
            }
        }
        else {
            Show-DrillMenu -Cat $drillCat -EnabledPkgs $ep
            $input = (Read-Host "  > ").Trim()
            $pkgs  = $Catalog[$drillCat]

            switch -Regex ($input) {
                '^[Bb]$' { $inDrill = $false }

                '^[Aa]$' {
                    $ep[$drillCat] = [System.Collections.Generic.List[string]]::new()
                    foreach ($p in $pkgs) { $ep[$drillCat].Add($p.Pkg) }
                }

                '^[Nn]$' {
                    $ep[$drillCat] = [System.Collections.Generic.List[string]]::new()
                }

                '^\d+$' {
                    $idx = [int]$input - 1
                    if ($idx -ge 0 -and $idx -lt $pkgs.Count) {
                        $id = $pkgs[$idx].Pkg
                        if ($ep[$drillCat] -contains $id) { $ep[$drillCat].Remove($id) | Out-Null }
                        else { $ep[$drillCat].Add($id) }
                    }
                }
            }
        }
    }
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
        else { Write-Warn "Defender real-time protection ENABLED — disable via Group Policy first"; $ok = $false }
    } catch { Write-Warn "Could not query Defender status — verify manually" }

    $build     = [System.Environment]::OSVersion.Version.Build
    $supported = @(19045, 22621, 22631, 26100)
    if ($build -in $supported) { Write-OK "OS build $build is supported" }
    else { Write-Warn "OS build $build not in tested list — continuing at your risk" }

    $freeGB = [math]::Round((Get-PSDrive (Get-Location).Drive.Name).Free / 1GB, 1)
    if ($freeGB -ge 90) { Write-OK "Free disk space: ${freeGB} GB" }
    else { Write-Warn "Free disk: ${freeGB} GB — 90+ GB recommended"; $ok = $false }

    return $ok
}

# ---------------------------------------------------------------------------
# ENSURE GIT
# ---------------------------------------------------------------------------
function Install-GitIfMissing {
    if (Get-Command git -ErrorAction SilentlyContinue) { return }
    Write-Step "Git not found — attempting auto-install..."
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
function Invoke-CloneRepo {
    Write-Step "Cloning mandiant/commando-vm..."
    if (Test-Path $RepoDestination) {
        Write-Warn "Destination already exists: $RepoDestination"
        $c = Read-Host "    Overwrite? (y/N)"
        if ($c -notin @('y','Y')) { throw "Aborted. Use -SkipClone to reuse existing clone." }
        Remove-Item $RepoDestination -Recurse -Force
    }
    git clone $RepoUrl $RepoDestination
    if ($LASTEXITCODE -ne 0) { throw "git clone failed (exit $LASTEXITCODE)" }
    Write-OK "Cloned to: $RepoDestination"
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
# UNBLOCK FILES
# ---------------------------------------------------------------------------
function Invoke-UnblockFiles {
    Write-Step "Unblocking repository files..."
    Get-ChildItem -Path $RepoDestination -Recurse | Unblock-File
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
        Write-OK "Mode: GUI — select 'BlackboxRed-Custom' from the Profile dropdown"
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

# Step 1 — Pre-checks
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

# Step 2 — Interactive package selection
Write-Host "`n  Press ENTER to open the package selection menu..." -ForegroundColor DarkGray
$null = Read-Host
$selectedPkgs = Invoke-SelectionMenu

# Step 3 — Confirm summary before proceeding
Write-Banner
Write-Step "Install summary"
Write-Divider
foreach ($cat in $Catalog.Keys) {
    $n = $selectedPkgs[$cat].Count
    if ($n -gt 0) {
        Write-Host ("  {0,-46}  {1} package(s)" -f $cat, $n) -ForegroundColor White
    }
}
Write-Divider
$grand = ($selectedPkgs.Values | ForEach-Object { $_ } | Measure-Object).Count
Write-Host ("  Total packages to install: ") -NoNewline -ForegroundColor DarkGray
Write-Host $grand -ForegroundColor Cyan
Write-Host ""

$confirm = Read-Host "  Proceed with installation? (y/N)"
if ($confirm -notin @('y','Y')) { Write-Host "`nCancelled.`n" -ForegroundColor Red; exit 0 }

# Step 4 — Build profile, clone, inject, launch
try {
    New-ProfileXml    -EnabledPkgs $selectedPkgs
    Install-GitIfMissing

    if (-not $SkipClone.IsPresent) {
        Invoke-CloneRepo
    } else {
        Write-Warn "Skipping clone (-SkipClone) — using: $RepoDestination"
        if (-not (Test-Path $RepoDestination)) { throw "Repository not found at: $RepoDestination" }
    }

    Invoke-InjectProfile
    Invoke-UnblockFiles
    Invoke-CommandoInstaller

    Write-Host "`n[+] Setup complete. Watch the Boxstarter window for progress." -ForegroundColor Green
    Write-Host "    Expect multiple automatic reboots — installation will resume after each one.`n" -ForegroundColor Green

} catch {
    Write-Host "`n[!] FATAL: $($_.Exception.Message)`n" -ForegroundColor Red
    exit 1
}
