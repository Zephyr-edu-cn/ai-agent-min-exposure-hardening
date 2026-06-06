# Windows OpenSSH Client Alias Verification

Collected on `2026-06-06`. Sensitive addresses and the private-key path are redacted.

## Sanitized Client Configuration

```sshconfig
Host agent-secure
    HostName <ubuntu-tailscale-ip>
    User deploy
    IdentityFile <dedicated-private-key>
    IdentitiesOnly yes
    ForwardAgent no

Host agent-secure-nat
    HostName <ubuntu-vm-nat-ip>
    User deploy
    IdentityFile <dedicated-private-key>
    IdentitiesOnly yes
    ForwardAgent no
```

`ssh -G agent-secure` confirmed the effective `hostname`, `user`, `identityfile`,
`identitiesonly yes`, and `forwardagent no` parameters.

## Live Login Retest

```powershell
ssh -o BatchMode=yes -o ConnectTimeout=12 agent-secure "whoami; hostname; id"
```

Result:

```text
deploy
agent-secure
uid=<redacted>(deploy) gid=<redacted>(deploy) groups=<redacted>(deploy),<redacted>(sudo),<redacted>(users),<redacted>(ssh-admins)
```

The `agent-secure-nat` emergency alias returned the same account, host, and
authorization-group boundary.

## Post-Boot Regression

- `ssh.service`: active
- `cockpit.socket`: active; listening only on `127.0.0.1:9090` and `[::1]:9090`
- `openclaw-gateway.service`: active; listening only on `127.0.0.1:18789` and `[::1]:18789`
- OpenSSH listens on port `22`; reachability remains constrained by UFW and the Tailnet policy.
