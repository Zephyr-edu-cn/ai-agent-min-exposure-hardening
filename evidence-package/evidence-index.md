# Evidence Index

## Implementation Freeze

当前实现阶段已封版。系统已完成账号隔离、OpenSSH 加固、UFW/Tailscale 访问收敛、Cockpit 与 OpenClaw Gateway loopback-only 部署、systemd 服务化以及成功/失败访问测试。最终核查未发现硬性 `FAIL`，剩余项均属于报告中需要解释的工程权衡或剩余风险。

## Core Evidence

| 证据项 | 文件或位置 | 说明 |
|---|---|---|
| Windows 环境 | `raw/windows-env.txt` | Windows OpenSSH、主机环境采集结果 |
| 访问测试矩阵输出 | `raw/09-access-matrix.txt` / `raw/09-access-matrix.json` | NAT/Tailnet、直连失败、隧道成功等客户端侧测试 |
| Ubuntu 服务状态 | `raw/10-server-state.txt` | OpenSSH、UFW、Tailscale、Fail2ban、Cockpit、OpenClaw、监听端口总采集 |
| OpenSSH 最终核查 | `tests/final-hardening-review.md` | `PASS / WARN / FAIL / REPORT_EVIDENCE` 总结 |
| 访问矩阵说明 | `tests/access-matrix.md` | 课程报告可引用的测试表 |
| SSH 加固片段 | `../config-snippets/sshd-hardening.conf` | 已落地到 `/etc/ssh/sshd_config.d/00-agent-lab-hardening.conf` |
| Tailscale 策略摘要 | `../config-snippets/tailscale-policy-redacted.hujson` | 脱敏 Grants：`windows-client -> agent-secure tcp:22`，`ssh: []` |
| OpenClaw systemd 服务 | `../config-snippets/openclaw-gateway.service` | loopback-only、token auth、`NoNewPrivileges=true` |
| OpenClaw 配置摘要 | `../config-snippets/openclaw-gateway-redacted.json5` | token 脱敏，不作为真实配置文件提交 |
| 风险分析 | `../risk-analysis.md` | 剩余风险、工程权衡和后续加固方向 |
| 架构图源文件 | `../architecture/minimal-exposure-architecture.mmd` | Mermaid 架构图，可渲染为 PNG/SVG |
| 截图清单 | `../screenshots-redacted/README.md` | 脱敏截图命名、命令和证明点 |

## Key Proof Points

- OpenSSH effective config: `pubkeyauthentication yes`、`passwordauthentication no`、`kbdinteractiveauthentication no`、`permitemptypasswords no`、`permitrootlogin no`、`allowgroups ssh-admins`、`allowagentforwarding no`、`allowtcpforwarding local`、`gatewayports no`、`maxauthtries 3`、`loglevel VERBOSE`。
- UFW: `Default: deny (incoming)`，仅允许 `22/tcp on tailscale0` 与 `<vmware-nat-host-ip> -> 22/tcp`。
- Tailscale: Windows `<windows-tailscale-ip>` 与 Ubuntu `<ubuntu-tailscale-ip>` 同 Tailnet 在线；Tailscale SSH 不作为主认证。
- Cockpit: 仅监听 `127.0.0.1:9090` 和 `[::1]:9090`。
- OpenClaw Gateway: 仅监听 `127.0.0.1:18789` 和 `[::1]:18789`，systemd `enabled` / `active`。
- 失败测试: 密码登录、root 登录、管理面直连、Gateway 直连、未带 token 或 scope 不足请求均失败。

## Screenshot Checklist

截图需要脱敏并放入 `screenshots-redacted/`。如果暂时不创建目录，也可在报告中按截图编号引用。

| 截图编号 | 内容 | 状态 |
|---|---|---|
| S01 | Ubuntu 版本、主机名、IP 地址 | 待整理 |
| S02 | `id deploy` / `id openclaw` / 用户组边界 | 待整理 |
| S03 | `sshd -T` effective hardening | 待整理 |
| S04 | `ufw status verbose` | 待整理 |
| S05 | Tailscale status 与 ACL/Grants 脱敏截图 | 待整理 |
| S06 | Fail2ban `sshd` jail 状态 | 待整理 |
| S07 | Cockpit loopback 监听与 SSH tunnel 成功访问 | 待整理 |
| S08 | OpenClaw Gateway loopback 监听与 SSH tunnel 成功访问 | 待整理 |
| S09 | Cockpit / OpenClaw NAT 或 Tailnet 直连失败 | 待整理 |
| S10 | OpenClaw `token_missing` / `missing scope` 日志或审计输出 | 待整理 |

## Report Warnings To Explain

- `sshd` 监听 `0.0.0.0:22` 是为了保留 VMware NAT 应急管理入口，实际可达路径由 UFW、Tailscale ACL、OpenSSH 公钥认证、`AllowGroups`、Fail2ban 共同收敛。
- Tailscale ACL 属于云端控制面配置，报告中使用脱敏截图或策略摘要作为证据，避免暴露真实账号和 Tailnet 信息。
- OpenClaw audit 的 `2 warn` 作为剩余风险记录；在当前 loopback-only、token/scope 拒绝和 SSH 隧道访问设计下，不构成最小暴露面目标的硬性失败。
