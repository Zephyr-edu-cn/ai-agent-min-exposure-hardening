param(
    [string]$VmxPath = ""
)

$ErrorActionPreference = "Continue"

$Root = Split-Path -Parent $PSScriptRoot
$OutDir = Join-Path $Root "evidence-package\raw"
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
$Out = Join-Path $OutDir "windows-env.txt"

function Section {
    param([string]$Name)
    Add-Content -Path $Out -Value ""
    Add-Content -Path $Out -Value ("=" * 80)
    Add-Content -Path $Out -Value $Name
    Add-Content -Path $Out -Value ("=" * 80)
}

function Run {
    param(
        [string]$Name,
        [scriptblock]$Block
    )
    Section $Name
    try {
        & $Block 2>&1 | Out-String | Add-Content -Path $Out
    } catch {
        Add-Content -Path $Out -Value ("ERROR: " + $_.Exception.Message)
    }
}

Set-Content -Path $Out -Value ("Collected at: " + (Get-Date -Format "yyyy-MM-dd HH:mm:ss"))

Run "Windows version" { cmd /c ver }
Run "PowerShell version" { $PSVersionTable }
Run "OpenSSH client" { cmd /c "ssh -V 2>&1" }
Run "ssh-agent service" { Get-Service ssh-agent | Select-Object Status,Name,StartType }
Run "Tailscale command" { Get-Command tailscale -ErrorAction SilentlyContinue | Select-Object Source,Version }
Run "Tailscale version" { if (Get-Command tailscale -ErrorAction SilentlyContinue) { tailscale version } else { "tailscale not found in PATH" } }
Run "TPM status" { Get-Tpm }
Run "VMware vmrun command" { Get-Command vmrun -ErrorAction SilentlyContinue | Select-Object Source,Version }

Run "VMware VMX summary (optional)" {
    if ($VmxPath -and (Test-Path -LiteralPath $VmxPath)) {
        Get-Content -LiteralPath $VmxPath |
            Select-String -Pattern "displayName|guestOS|memsize|numvcpus|cpuid.coresPerSocket|ethernet0.connectionType|scsi0:0.fileName|sata0:1.fileName|usb.present"
    } elseif ($VmxPath) {
        "VMX file not found at the supplied path"
    } else {
        "VMX collection skipped; pass -VmxPath to include a local VM summary"
    }
}

Write-Host "Wrote $Out"
