# 自托管智能体应用的最小暴露面部署与安全边界验证

## 项目目标

本项目面向自托管智能体应用的安全部署场景，构建并验证一个最小暴露面的访问架构。项目重点不是模型效果，而是智能体系统在真实落地时的身份边界、网络边界、服务账号边界、管理面暴露面和 Gateway 认证边界。

## 封版状态

实现阶段已封版：账号隔离、OpenSSH 加固、UFW/Tailscale 访问收敛、Cockpit 与 OpenClaw Gateway loopback-only 部署、systemd 服务化以及成功/失败访问测试均已完成。最终核查未发现硬性 `FAIL`，剩余项作为工程权衡或剩余风险在报告中解释。

## 当前环境

| 项目 | 配置 |
|---|---|
| 主机系统 | Windows，OpenSSH_for_Windows_9.5p2 |
| 虚拟化 | VMware Workstation NAT |
| 服务器系统 | Ubuntu Server 24.04.4 LTS |
| Hostname | `agent-secure` |
| VMware NAT IP | `<ubuntu-vm-nat-ip>` |
| Tailscale Windows IP | `<windows-tailscale-ip>` |
| Tailscale Ubuntu IP | `<ubuntu-tailscale-ip>` |
| 管理账号 | `deploy` |
| 服务账号 | `openclaw` |
| OpenClaw | `OpenClaw 2026.5.28 (e932160)` |

## 材料入口

- [evidence-package/evidence-index.md](evidence-package/evidence-index.md)：证据索引，说明每类证据证明什么。
- [evidence-package/tests/final-hardening-review.md](evidence-package/tests/final-hardening-review.md)：最终 OpenSSH / UFW / Tailscale / Fail2Ban / 端口暴露核查。
- [evidence-package/tests/windows-ssh-client-alias.md](evidence-package/tests/windows-ssh-client-alias.md)：Windows SSH 别名、有效参数与现场登录复测。
- [report.md](report.md)：实验报告正文。
- [risk-analysis.md](risk-analysis.md)：威胁模型、当前控制与剩余风险。
- [参考资料.md](参考资料.md)：参考文献和引用边界。
- [PUBLIC_RELEASE_CHECKLIST.md](PUBLIC_RELEASE_CHECKLIST.md)：公开仓库发布前检查清单。

## 架构摘要

```text
Windows Client
  |-- OpenSSH public key
  |-- Tailscale private network
  |-- SSH local port forwarding
  v
Ubuntu Server: agent-secure
  |-- sshd: reachable on tailscale0:22 and VMware host emergency path
  |-- Cockpit: 127.0.0.1:9090 / [::1]:9090 only
  |-- OpenClaw Gateway: 127.0.0.1:18789 / [::1]:18789 only
  |-- UFW: default deny incoming
  |-- Fail2ban: sshd jail enabled
```

## 已实现边界

| 边界 | 实现 |
|---|---|
| 账号边界 | `deploy` 负责远程管理，`openclaw` 仅运行 OpenClaw，不属于 `sudo` 或 `ssh-admins` |
| SSH 认证 | 公钥登录成功，密码登录失败，root 登录失败，`AllowGroups ssh-admins` |
| SSH 转发与审计 | 禁用 Agent Forwarding，仅允许 local forwarding，`GatewayPorts no`，`MaxAuthTries 3`，`LogLevel VERBOSE` |
| 主机防火墙 | UFW 默认拒绝入站，仅允许 `tailscale0:22` 和 `<vmware-nat-host-ip> -> 22` |
| 私有组网 | Tailscale 已加入同一 Tailnet，ACL/Grants 仅允许 `windows-client -> agent-secure tcp:22` |
| 管理面 | Cockpit 仅监听 loopback，NAT/Tailnet 直连失败，SSH 隧道访问成功 |
| Agent Gateway | OpenClaw Gateway 由 systemd 持久化运行，仅监听 loopback，token 认证，直连失败，隧道成功 |
| 失败访问 | 密码登录、root 登录、Cockpit 直连、OpenClaw 直连、未带 token 请求均失败 |

## 回归验证

Windows 侧访问面回归：

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\check-access-matrix.ps1
```

脚本会验证：

- NAT 应急 SSH 可达。
- OpenSSH via Tailnet 可达。
- NAT/Tailnet 直连 Cockpit 失败。
- NAT/Tailnet 直连 OpenClaw Gateway 失败。
- OpenSSH 公钥登录成功。
- OpenSSH 密码登录和 root 登录失败。
- Cockpit 通过 SSH tunnel 成功。
- OpenClaw Gateway 通过 SSH tunnel 成功。

输出位置：

```text
evidence-package/raw/09-access-matrix.txt
evidence-package/raw/09-access-matrix.json
```

Ubuntu 侧服务状态采集：

```bash
bash /path/to/check-server-state.sh | tee server-state.txt
```

输出保存位置：

```text
evidence-package/raw/10-server-state.txt
```

## 关键验证结果

| 测试 | 结果 |
|---|---|
| `deploy` 公钥登录 | 成功 |
| `deploy` 密码登录 | `Permission denied (publickey)` |
| `root` 登录 | `Permission denied (publickey)` |
| `<ubuntu-vm-nat-ip>:9090` | 失败 |
| `<ubuntu-tailscale-ip>:9090` | 失败 |
| `<ubuntu-vm-nat-ip>:18789` | 失败 |
| `<ubuntu-tailscale-ip>:18789` | 失败 |
| `127.0.0.1:9090` via SSH tunnel | 成功 |
| `127.0.0.1:18789` via SSH tunnel | 成功 |
| OpenClaw no-token access | `token_missing` |
| OpenClaw insufficient scope | `missing scope: operator.read` |
| `openclaw-gateway` after reboot | `enabled` / `active` |

说明：`check-access-matrix.ps1` 主要覆盖网络可达性、SSH 认证和 SSH tunnel 路径；OpenClaw no-token 与 insufficient-scope 拒绝结果来自脱敏日志、audit 输出或手工 HTTP 验证记录。

## 工程价值

本项目展示了自托管智能体应用部署中的访问面收敛、权限边界设计和可复查安全验证流程：

- 不只关注智能体能否运行，也关注运行边界是否可控。
- 将 SSH、UFW、Tailscale、Cockpit、OpenClaw Gateway 组合为可验证的访问架构。
- 用成功访问与失败访问共同证明安全边界，而不是只展示功能截图。
- 通过脚本固化访问面回归验证，体现可复现、可审计和防回退意识。

## 敏感信息处理

提交报告或材料时必须脱敏：

- 不提交 SSH 私钥。
- 不展示 OpenClaw Gateway token。
- 不展示 API Key。
- 账号邮箱、设备名、完整公网地址按需打码。
- 截图中 token、邮箱、个人账号信息必须遮挡。
