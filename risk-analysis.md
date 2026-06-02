# 风险分析

## 威胁模型

本项目假设服务器运行在个人虚拟机环境中，但局域网和 Tailnet 均不天然可信。潜在风险包括：

- 局域网中存在被感染主机，尝试扫描或访问管理端口。
- SSH 弱口令、root 远程登录或非授权用户登录导致服务器失陷。
- Web 管理面暴露后可修改系统用户、服务和配置。
- OpenClaw Gateway 暴露后可能触发工具调用、文件访问、凭据泄露或越权操作。
- OpenClaw token、API Key 等凭据进入截图、报告或公开脚本。
- 提示注入或恶意输入诱导智能体读取文件、调用工具或泄露配置。
- Tailscale 默认 allow-all 策略导致 Tailnet 内设备横向访问。

## 当前控制

| 风险 | 当前控制 | 验证证据 |
|---|---|---|
| SSH 密码爆破 | 禁用密码登录，启用 Fail2ban `sshd` jail | 密码登录失败；`fail2ban-client status sshd` |
| root 远程登录 | `PermitRootLogin no` | root 登录失败 |
| 非授权账号登录 | `AllowGroups ssh-admins` | `openclaw` 不属于 `ssh-admins` |
| SSH Agent 滥用 | `AllowAgentForwarding no` | `sshd -T` 输出 |
| 非必要端口暴露 | UFW 默认拒绝入站 | `ufw status verbose` |
| Tailnet 横向访问 | ACL/Grants 仅允许 `windows-client -> agent-secure tcp:22` | Tailscale Access Controls 策略 |
| Web 管理面暴露 | Cockpit 仅监听 loopback，直连 NAT/Tailnet 失败 | `ss -tulpn` 与 `Test-NetConnection` |
| Agent Gateway 暴露 | OpenClaw Gateway 仅监听 loopback，直连 NAT/Tailnet 失败 | `ss -tulpn` 与 `Test-NetConnection` |
| 未授权 Gateway 操作 | OpenClaw token 认证与 scope 检查 | `token_missing`、`missing scope: operator.read` |
| 服务重启后回退 | OpenClaw Gateway systemd 持久化并重启验证 | `enabled` / `active` / loopback 监听 |

## 剩余风险

### 1. OpenClaw token 明文配置

OpenClaw doctor 提示 `gateway.auth.token` 属于 plaintext secret-bearing config。当前通过以下方式降低风险：

- OpenClaw 运行在独立 `openclaw` 服务账号下。
- `/opt/openclaw/.openclaw` 权限已收紧到 `700`，`openclaw.json` 权限为 `600`。
- 报告与截图中不展示 token。

后续改进：

- 迁移到 OpenClaw SecretRefs。
- 使用系统级 secret store 或受限环境文件。
- 定期轮换 Gateway token。

### 2. API Key 未配置

实验中未配置真实模型 API Key，因此 OpenClaw 日志出现 `No API key found for provider openai`。这不是部署边界验证失败，而是刻意避免真实凭据进入实验截图和报告。

后续改进：

- 若需要验证模型调用，可使用最小权限 API Key。
- 凭据仅放入 `openclaw` 用户可读的环境文件。
- 配合审计日志记录模型调用与工具调用。

### 3. VMware NAT 应急 SSH

当前保留 `<vmware-nat-host-ip> -> 22/tcp` 作为宿主机应急管理路径。这是工程权衡，不作为主要远程入口。

后续改进：

- 在项目最终演示环境中，可删除该规则，仅保留 Tailscale 私有访问。
- 或使用临时维护窗口按需开启。

### 4. Cockpit 管理权限

Cockpit 已收敛到 loopback，但登录后仍可能具备系统管理能力。

后续改进：

- 限制 Cockpit 可用模块。
- 启用更严格的二次认证。
- 将 Cockpit 仅用于状态查看，避免日常修改关键配置。

### 5. Agent 工具越权

OpenClaw 已限制网络暴露和 token 认证，安全审计当前为 `0 critical · 2 warn · 1 info`。剩余 warning 中，`gateway.trusted_proxies_missing` 可通过保持 Control UI local-only 规避；`gateway.probe_failed missing scope: operator.read` 反映未携带足够 scope 的探测被拒绝。智能体工具本身仍可能带来文件访问、命令执行和提示注入风险。

后续改进：

- 最小化 enabled skills/tools。
- 对高风险工具设置人工确认。
- 限制工作目录和文件访问范围。
- 审计工具调用日志。
- 使用 prompt injection 防护和输入来源标注。

## 工程结论

本项目不声称消除所有风险，而是通过身份、认证、网络、服务和验证五层控制，将高价值管理面与 Agent Gateway 从不可信网络中移除，并用回归脚本固化安全边界验证。其核心价值在于：部署不是以“服务能访问”为终点，而是以“只有预期主体能通过预期路径访问”为验收标准。
