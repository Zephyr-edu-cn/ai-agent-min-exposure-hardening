# Public Redacted Screenshots

本目录用于 GitHub、作品集或投递材料中的公开截图。相比 `screenshots-redacted/`，这里进一步遮挡了 Windows 本地路径、私钥文件名、Tailscale/VMware IP、终端用户提示和不必要的主机信息。

## Files

| 文件 | 用途 |
|---|---|
| `01_sshd_T_effective_config.png` | OpenSSH effective hardening |
| `02_ufw_status_verbose.png` | UFW 默认拒绝入站与必要 SSH 入口 |
| `03_listening_ports_ss_tulpn.png` | Cockpit/OpenClaw loopback-only 监听证明 |
| `04_tailscale_acl_grants_redacted.png` | Tailscale Access Controls 可视化策略 |
| `05_fail2ban_sshd_status.png` | Fail2ban `sshd` jail 状态 |
| `06_cockpit_tunnel_success.png` | Cockpit 通过 SSH tunnel 访问成功 |
| `07_openclaw_tunnel_success.png` | OpenClaw Gateway 通过 SSH tunnel 访问成功并要求认证 |
| `08_09_direct_fail_ports.png` | NAT/Tailnet 直连 `9090` / `18789` 失败 |
| `09_tailscale_ssh_disabled_or_json_policy.png` | Tailscale JSON 策略：`grants` 与 `ssh: []` |
| `10_openclaw_audit_or_token_reject.png` | OpenClaw security audit 与剩余 warning |

## Public-Use Notes

- 不包含 SSH 私钥、真实 token、API Key、密码或邮箱。
- IP 和本地路径已遮挡；保留端口、配置字段和成功/失败结果。
- 公开展示时优先使用本目录，不要使用 `screenshots-redacted/` 或 `evidence-package/raw/`。
