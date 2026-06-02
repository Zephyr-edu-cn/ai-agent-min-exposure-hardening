# Final OpenSSH Hardening Review

Source evidence:

- `evidence-package/raw/10-server-state.txt`, collected at `2026-06-01 09:45:55 UTC`.
- `evidence-package/tests/access-matrix.md`.
- `config-snippets/sshd-hardening.conf`.
- `config-snippets/tailscale-policy-redacted.hujson`.

## PASS

- `PubkeyAuthentication` is enabled: `pubkeyauthentication yes`.
- Password login is disabled: `passwordauthentication no`.
- Keyboard-interactive login is disabled: `kbdinteractiveauthentication no`.
- Empty-password login is disabled: `permitemptypasswords no`.
- Root SSH login is disabled: `permitrootlogin no`.
- SSH login scope is restricted with `allowgroups ssh-admins`.
- `deploy` is in `sudo` and `ssh-admins`; `openclaw` is only in its own service group.
- SSH Agent Forwarding is disabled: `allowagentforwarding no`.
- X11 Forwarding is disabled: `x11forwarding no`.
- TCP Forwarding is limited to local forwarding: `allowtcpforwarding local`.
- Remote forwarded ports cannot listen on non-loopback addresses: `gatewayports no`.
- Authentication attempts are reduced from the OpenSSH default: `maxauthtries 3`.
- SSH logging is more audit-friendly: `loglevel VERBOSE`.
- The SSH service accepted the hardened configuration and reloaded successfully: `ExecReload=/usr/sbin/sshd -t (status=0/SUCCESS)`.
- UFW is active and defaults to denying incoming traffic.
- UFW no longer exposes `22/tcp` to `Anywhere`; it allows `22/tcp` on `tailscale0` and the VMware host emergency path `<vmware-nat-host-ip> -> 22`.
- Tailscale is connected, with Windows `<windows-tailscale-ip>` and Ubuntu `<ubuntu-tailscale-ip>` in the same Tailnet.
- Tailscale SSH is not used as the primary authentication path; OpenSSH public-key authentication remains the main control.
- Fail2ban is enabled for `sshd`.
- Cockpit listens only on `127.0.0.1:9090` and `[::1]:9090`.
- OpenClaw Gateway listens only on `127.0.0.1:18789` and `[::1]:18789`.
- `ss -tulpn` does not show Cockpit or OpenClaw Gateway exposed on `0.0.0.0`.
- OpenClaw runs as the dedicated `openclaw` service account.
- OpenClaw Gateway is managed by systemd and is `enabled` / `active`.
- OpenClaw config permissions are restricted: `/opt/openclaw/.openclaw` is `700`, and `openclaw.json` is `600`.

## WARN

- `sshd` listens on `0.0.0.0:22` and `[::]:22`. This is acceptable only because UFW and Tailscale ACL/Grants restrict the reachable path. Explain this as a firewall and identity-policy boundary, not as loopback-only SSH.
- The Tailscale Access Controls policy should be captured as a redacted screenshot or exported policy evidence. The project snippet now matches the intended grants model: `windows-client -> agent-secure tcp:22`, with `ssh: []`.
- OpenClaw security audit reports `0 critical · 2 warn · 1 info`. The two warnings should be explained: `gateway.trusted_proxies_missing` is acceptable while keeping the UI local-only, and `gateway.probe_failed missing scope: operator.read` shows an insufficient-scope request was rejected.

## FAIL

- No mandatory hardening failure is visible in the current evidence.

## REPORT_EVIDENCE

Use these command outputs or screenshots in the report:

- `sudo sshd -T | grep -Ei 'passwordauthentication|kbdinteractiveauthentication|permitemptypasswords|permitrootlogin|pubkeyauthentication|allowgroups|allowusers|allowagentforwarding|allowtcpforwarding|x11forwarding|gatewayports|maxauthtries|loglevel'`
- `sudo ufw status verbose`
- `tailscale status`
- `tailscale ip -4`
- Tailscale Admin Console Access Controls screenshot showing the restricted grant and `ssh: []`.
- `sudo fail2ban-client status sshd`
- `systemctl status cockpit.socket --no-pager`
- `systemctl status openclaw-gateway --no-pager`
- `ss -tulpn | grep -E ':22|:9090|:18789'`
- Windows tests showing `Test-NetConnection <ubuntu-tailscale-ip> -Port 9090` and `Test-NetConnection <ubuntu-tailscale-ip> -Port 18789` both fail.
- SSH tunnel screenshots showing Cockpit and OpenClaw are accessible only through local forwarding.
