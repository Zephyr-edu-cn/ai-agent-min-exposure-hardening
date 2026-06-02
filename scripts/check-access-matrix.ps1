param(
    [string]$NatHost = "<ubuntu-vm-nat-ip>",
    [string]$TailnetHost = "<ubuntu-tailscale-ip>",
    [string]$SshUser = "deploy",
    [string]$KeyPath = "$env:USERPROFILE\.ssh\<deploy-key-file>",
    [int]$CockpitLocalPort = 19090,
    [int]$OpenClawLocalPort = 18790,
    [string]$OutputPath = ""
)

$ErrorActionPreference = "Continue"

$Root = Split-Path -Parent $PSScriptRoot
if (-not $OutputPath) {
    $RawDir = Join-Path $Root "evidence-package\raw"
    New-Item -ItemType Directory -Force -Path $RawDir | Out-Null
    $OutputPath = Join-Path $RawDir "09-access-matrix.txt"
}

$Rows = New-Object System.Collections.Generic.List[object]

function Add-Check {
    param(
        [string]$Name,
        [string]$Expected,
        [string]$Actual,
        [bool]$Pass
    )
    $Rows.Add([PSCustomObject]@{
        Time = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
        Name = $Name
        Expected = $Expected
        Actual = $Actual
        Result = $(if ($Pass) { "PASS" } else { "FAIL" })
    }) | Out-Null
}

function Test-TcpFast {
    param(
        [string]$HostName,
        [int]$Port,
        [int]$TimeoutMs = 3000
    )
    $client = New-Object System.Net.Sockets.TcpClient
    try {
        $iar = $client.BeginConnect($HostName, $Port, $null, $null)
        $ok = $iar.AsyncWaitHandle.WaitOne($TimeoutMs, $false)
        if (-not $ok) {
            return $false
        }
        $client.EndConnect($iar)
        return $client.Connected
    } catch {
        return $false
    } finally {
        $client.Close()
    }
}

function Invoke-SshCheck {
    param([string[]]$SshArgs)
    $output = & ssh @SshArgs 2>&1
    $code = $LASTEXITCODE
    return [PSCustomObject]@{
        ExitCode = $code
        Output = ($output -join "`n")
    }
}

function Start-Tunnel {
    param(
        [int]$LocalPort,
        [int]$RemotePort,
        [string]$RemoteHost
    )

    $sshArgs = @(
        "-o", "ExitOnForwardFailure=yes",
        "-o", "BatchMode=yes",
        "-i", $KeyPath,
        "-N",
        "-L", "${LocalPort}:127.0.0.1:${RemotePort}",
        "${SshUser}@${RemoteHost}"
    )

    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = "ssh"
    $psi.Arguments = ($sshArgs | ForEach-Object {
        if ($_ -match '[\s"]') {
            '"' + ($_ -replace '"', '\"') + '"'
        } else {
            $_
        }
    }) -join " "
    $psi.UseShellExecute = $false
    $psi.RedirectStandardError = $true
    $psi.RedirectStandardOutput = $true
    $proc = [System.Diagnostics.Process]::Start($psi)
    Start-Sleep -Seconds 3
    return $proc
}

function Stop-Tunnel {
    param($Process)
    if ($null -ne $Process -and -not $Process.HasExited) {
        $Process.Kill()
        $Process.WaitForExit()
    }
}

Set-Content -Path $OutputPath -Value "Access surface regression check"
Add-Content -Path $OutputPath -Value ("Collected at: " + (Get-Date -Format "yyyy-MM-dd HH:mm:ss"))
Add-Content -Path $OutputPath -Value "NAT host: $NatHost"
Add-Content -Path $OutputPath -Value "Tailnet host: $TailnetHost"
Add-Content -Path $OutputPath -Value "SSH user: $SshUser"
Add-Content -Path $OutputPath -Value "Key path: $KeyPath"
Add-Content -Path $OutputPath -Value ""

try {
    if (-not (Test-Path -LiteralPath $KeyPath)) {
        Add-Check "SSH key exists" "key file present" "missing: $KeyPath" $false
    } else {
        Add-Check "SSH key exists" "key file present" "present: $KeyPath" $true
    }
} catch {
    Add-Check "SSH key exists" "key file present" ("cannot access: " + $_.Exception.Message) $false
}

$nat22 = Test-TcpFast $NatHost 22
Add-Check "NAT emergency SSH TCP" "reachable from VMware host" "Tcp=$nat22" ($nat22 -eq $true)

$tail22 = Test-TcpFast $TailnetHost 22
Add-Check "Tailnet SSH TCP" "reachable" "Tcp=$tail22" ($tail22 -eq $true)

$natCockpit = Test-TcpFast $NatHost 9090
Add-Check "NAT direct Cockpit" "blocked" "Tcp=$natCockpit" ($natCockpit -eq $false)

$tailCockpit = Test-TcpFast $TailnetHost 9090
Add-Check "Tailnet direct Cockpit" "blocked" "Tcp=$tailCockpit" ($tailCockpit -eq $false)

$natGateway = Test-TcpFast $NatHost 18789
Add-Check "NAT direct OpenClaw Gateway" "blocked" "Tcp=$natGateway" ($natGateway -eq $false)

$tailGateway = Test-TcpFast $TailnetHost 18789
Add-Check "Tailnet direct OpenClaw Gateway" "blocked" "Tcp=$tailGateway" ($tailGateway -eq $false)

$sshNat = Invoke-SshCheck @(
    "-o", "BatchMode=yes",
    "-o", "PreferredAuthentications=publickey",
    "-o", "PasswordAuthentication=no",
    "-i", $KeyPath,
    "${SshUser}@${NatHost}",
    "whoami; hostname; id"
)
Add-Check "OpenSSH public key via NAT" "success as deploy on agent-secure" ($sshNat.Output -replace "`n", " | ") ($sshNat.ExitCode -eq 0 -and $sshNat.Output -match "deploy" -and $sshNat.Output -match "agent-secure")

$sshTail = Invoke-SshCheck @(
    "-o", "BatchMode=yes",
    "-o", "PreferredAuthentications=publickey",
    "-o", "PasswordAuthentication=no",
    "-i", $KeyPath,
    "${SshUser}@${TailnetHost}",
    "whoami; hostname; id"
)
Add-Check "OpenSSH public key via Tailnet" "success as deploy on agent-secure" ($sshTail.Output -replace "`n", " | ") ($sshTail.ExitCode -eq 0 -and $sshTail.Output -match "deploy" -and $sshTail.Output -match "agent-secure")

$sshPassword = Invoke-SshCheck @(
    "-o", "PreferredAuthentications=password",
    "-o", "PubkeyAuthentication=no",
    "-o", "NumberOfPasswordPrompts=1",
    "${SshUser}@${NatHost}",
    "whoami"
)
Add-Check "OpenSSH password login" "blocked" ($sshPassword.Output -replace "`n", " | ") ($sshPassword.ExitCode -ne 0 -and $sshPassword.Output -match "Permission denied")

$sshRoot = Invoke-SshCheck @(
    "-o", "NumberOfPasswordPrompts=1",
    "root@${NatHost}",
    "whoami"
)
Add-Check "OpenSSH root login" "blocked" ($sshRoot.Output -replace "`n", " | ") ($sshRoot.ExitCode -ne 0 -and $sshRoot.Output -match "Permission denied")

$cockpitTunnel = $null
try {
    $cockpitTunnel = Start-Tunnel -LocalPort $CockpitLocalPort -RemotePort 9090 -RemoteHost $TailnetHost
    $ok = Test-TcpFast "127.0.0.1" $CockpitLocalPort
    Add-Check "Cockpit via SSH tunnel" "reachable on 127.0.0.1:$CockpitLocalPort" "Tcp=$ok" ($ok -eq $true)
} catch {
    Add-Check "Cockpit via SSH tunnel" "reachable on 127.0.0.1:$CockpitLocalPort" $_.Exception.Message $false
} finally {
    Stop-Tunnel $cockpitTunnel
}

$gatewayTunnel = $null
try {
    $gatewayTunnel = Start-Tunnel -LocalPort $OpenClawLocalPort -RemotePort 18789 -RemoteHost $TailnetHost
    $ok = Test-TcpFast "127.0.0.1" $OpenClawLocalPort
    Add-Check "OpenClaw Gateway via SSH tunnel" "reachable on 127.0.0.1:$OpenClawLocalPort" "Tcp=$ok" ($ok -eq $true)
} catch {
    Add-Check "OpenClaw Gateway via SSH tunnel" "reachable on 127.0.0.1:$OpenClawLocalPort" $_.Exception.Message $false
} finally {
    Stop-Tunnel $gatewayTunnel
}

$Rows | Format-Table -AutoSize | Out-String | Add-Content -Path $OutputPath
$Rows | ConvertTo-Json -Depth 4 | Set-Content -Path ($OutputPath -replace "\.txt$", ".json")

$failures = @($Rows | Where-Object { $_.Result -ne "PASS" })
if ($failures.Count -gt 0) {
    Write-Host "Access matrix check completed with failures. See $OutputPath"
    $Rows | Format-Table -AutoSize
    exit 1
}

Write-Host "Access matrix check passed. Wrote $OutputPath"
$Rows | Format-Table -AutoSize
