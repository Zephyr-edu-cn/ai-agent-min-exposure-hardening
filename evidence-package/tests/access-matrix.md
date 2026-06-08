# Access Matrix

环境日期：2026-05-31

## 主机环境

| 项目 | 结果 |
|---|---|
| Ubuntu | Ubuntu 24.04.4 LTS |
| Hostname | agent-secure |
| VM IP | <ubuntu-vm-nat-ip> |
| 网络模式 | VMware NAT |
| SSH 管理账号 | deploy |
| OpenClaw 服务账号 | openclaw |

## SSH 边界

| 测试项 | 命令/方法 | 预期 | 实际 |
|---|---|---|---|
| deploy 公钥登录 | `ssh -o PreferredAuthentications=publickey -o PasswordAuthentication=no -i <key> deploy@<ubuntu-vm-nat-ip> "whoami; hostname; id"` | 成功 | 成功，输出 `deploy`、`agent-secure`，用户组包含 `sudo` 与 `ssh-admins` |
| deploy 密码登录 | `ssh -o PreferredAuthentications=password -o PubkeyAuthentication=no -o NumberOfPasswordPrompts=1 deploy@<ubuntu-vm-nat-ip> "whoami"` | 失败 | 失败，`Permission denied (publickey).` |
| root 登录 | `ssh -o NumberOfPasswordPrompts=1 root@<ubuntu-vm-nat-ip> "whoami"` | 失败 | 失败，`Permission denied (publickey).` |
| SSH 有效配置 | `sudo sshd -T | grep -E '...'` | 加固项生效 | `passwordauthentication no`、`permitrootlogin no`、`allowgroups ssh-admins`、`allowtcpforwarding local` |

## UFW 与 Cockpit 管理面

| 测试项 | 命令/方法 | 预期 | 实际 |
|---|---|---|---|
| UFW 状态 | `sudo ufw status verbose` | active，默认拒绝入站，仅保留 Tailscale 接口 SSH 与 VMware NAT 宿主机应急 SSH | 成功，`Default: deny (incoming), allow (outgoing)`，`22/tcp on tailscale0 ALLOW IN Anywhere`，`22/tcp ALLOW IN <vmware-nat-host-ip>`，无 `22/tcp Anywhere` |
| SSH 直连 | `Test-NetConnection <ubuntu-vm-nat-ip> -Port 22` | 成功 | `TcpTestSucceeded : True` |
| Cockpit 监听 | `systemctl status cockpit.socket --no-pager; ss -tulpn \| grep 9090` | 只监听回环地址 | `127.0.0.1:9090` 与 `[::1]:9090` |
| Cockpit NAT 直连 | `Test-NetConnection <ubuntu-vm-nat-ip> -Port 9090` | 失败 | `TcpTestSucceeded : False` |
| Cockpit Tailnet 直连 | `Test-NetConnection <ubuntu-tailscale-ip> -Port 9090` | 失败 | `TcpTestSucceeded : False` |
| Cockpit 隧道 | `ssh -L 9090:127.0.0.1:9090 deploy@<ubuntu-tailscale-ip>` 后访问 `https://127.0.0.1:9090` | 成功 | 成功，浏览器进入 Cockpit 登录页 |

## Tailscale 私有组网

| 测试项 | 命令/方法 | 预期 | 实际 |
|---|---|---|---|
| Windows Tailscale | `tailscale version; tailscale ip -4; tailscale status` | Windows 加入 Tailnet | 版本 `1.98.4`，IP `<windows-tailscale-ip>`，设备在线 |
| Ubuntu Tailscale | `tailscale version; tailscale ip -4; tailscale status; ip -br addr` | Ubuntu 加入同一 Tailnet | 版本 `1.98.4`，IP `<ubuntu-tailscale-ip>`，`tailscale0` 存在 |
| OpenSSH via Tailnet | `ssh -i <key> deploy@<ubuntu-tailscale-ip> "whoami; hostname; id"` | 成功，仍使用 OpenSSH 公钥认证 | 成功，输出 `deploy`、`agent-secure`、`ssh-admins` |
| Tailscale SSH | `sudo tailscale up --ssh=false` | 不启用 Tailscale SSH 作为主认证 | 已禁用，实验主认证仍为 OpenSSH 公钥 |
| UFW 收敛 | `sudo ufw status verbose` | SSH 入口限制为 `tailscale0` 与本机 NAT 应急地址 | `22/tcp on tailscale0 ALLOW IN Anywhere`，`22/tcp ALLOW IN <vmware-nat-host-ip>`，无 `22/tcp Anywhere` |
| Fail2ban sshd jail | `sudo fail2ban-client status; sudo fail2ban-client status sshd` | `sshd` jail 启用 | `Number of jail: 1`，`Jail list: sshd`，`Status for the jail: sshd` |
| Tailscale ACL/Grants | Admin Console Access Controls | 仅允许 Windows 客户端访问 Ubuntu 的 `22/tcp`，清空 Tailscale SSH 规则 | 已将默认 allow-all 改为 `windows-client -> agent-secure tcp:22`，`ssh: []` |
| VMware NAT 应急 SSH | `ssh -i <key> deploy@<ubuntu-vm-nat-ip> "whoami; hostname; id"` | 成功 | 成功，作为本机应急管理通道 |
| Tailscale 管理面直连 | `Test-NetConnection <ubuntu-tailscale-ip> -Port 9090` | 失败 | `TcpTestSucceeded : False` |
| Tailscale Gateway 直连 | `Test-NetConnection <ubuntu-tailscale-ip> -Port 18789` | 失败 | `TcpTestSucceeded : False` |

## OpenClaw Gateway

| 测试项 | 命令/方法 | 预期 | 实际 |
|---|---|---|---|
| 服务账号 | `id openclaw; groups openclaw` | 不属于 `sudo` 或 `ssh-admins` | `uid=112(openclaw) gid=113(openclaw) groups=113(openclaw)` |
| 安装版本 | `openclaw --version` | OpenClaw 可用 | `OpenClaw 2026.5.28 (e932160)` |
| Gateway 运行 | `openclaw gateway run --bind loopback --port 18789 --auth token --tailscale off` | ready | 日志显示 `gateway ready` |
| Gateway 监听 | `ss -tulpn | grep 18789` | 只监听回环地址 | `127.0.0.1:18789` 与 `[::1]:18789` |
| Gateway 直连 | `Test-NetConnection <ubuntu-vm-nat-ip> -Port 18789` | 失败 | `TcpTestSucceeded : False` |
| Gateway 隧道 | `ssh -L 18789:127.0.0.1:18789 deploy@<ubuntu-vm-nat-ip>` 后测 `127.0.0.1:18789` | 成功 | `TcpTestSucceeded : True` |
| Gateway systemd 持久化 | `systemctl is-enabled openclaw-gateway; systemctl is-active openclaw-gateway` | enabled / active | 重启后输出 `enabled`、`active` |
| Gateway 重启后监听 | 重启后执行 `ss -tulpn | grep 18789` | 仍只监听回环地址 | `127.0.0.1:18789` 与 `[::1]:18789` |
| 未授权访问 | 浏览器访问隧道后的 Control UI，但未提供 token | 拒绝 | 日志显示 `unauthorized ... reason=token_missing` |
| 权限 scope | 未携带足够 scope 请求 `config.get` | 拒绝 | 日志显示 `missing scope: operator.read` |
| 健康检查 | `health` 请求 | 可访问 | 日志显示 `health ... cached=true` |
| OpenClaw 配置目录权限 | `ls -ld /opt/openclaw/.openclaw; ls -l openclaw.json` | 目录 `700`，配置文件 `600` | `drwx------`，`openclaw.json -rw-------` |
| OpenClaw 安全审计 | `openclaw security audit --deep` | 无 critical | `0 critical · 2 warn · 1 info` |

## 风险记录

| 风险 | 当前控制 | 后续改进 |
|---|---|---|
| OpenClaw token 明文配置 | `~/.openclaw` 权限收紧到 `700`，`openclaw.json` 为 `600`，报告中 token 全部脱敏 | 迁移到 OpenClaw SecretRefs 或系统级 secret store |
| API Key 缺失 | 未配置真实模型 API Key，避免凭据进入实验截图和报告 | 若后续需要模型能力，使用服务账号环境文件并限制权限 |
| Web 管理面高价值攻击面 | UFW 拦截 9090 直连，仅允许 SSH 隧道 | 可进一步限制 Cockpit 管理权限并启用二次认证 |
| Gateway 工具越权 | Gateway 绑定回环地址、启用 token、禁用公网/Tailscale Funnel | 最小化 tools/skills allowlist，启用审计日志和 token 轮换 |

