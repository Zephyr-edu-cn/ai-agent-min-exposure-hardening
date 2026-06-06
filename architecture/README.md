# Architecture

## Diagram Source

`minimal-exposure-architecture.mmd` 是报告和项目总结使用的架构图源文件。可用 Mermaid 渲染为 PNG/SVG 后放入报告。

## Diagram Message

架构图表达三层边界：

- 访问边界：Windows 客户端通过 Tailscale 私有网络和 OpenSSH 公钥认证进入 Ubuntu。
- 管理边界：Cockpit 与 OpenClaw Gateway 只监听 loopback，远程访问必须经过 SSH 本地端口转发。
- 权限边界：`deploy` 负责远程管理，`openclaw` 仅运行 Gateway，不具备 `sudo` 或 SSH 管理组权限。

## Caption

图：自托管智能体应用最小暴露面访问架构。SSH 是唯一远程入口，受 OpenSSH 公钥认证、`AllowGroups`、UFW、Tailscale ACL/Grants 和 Fail2ban 共同约束；Cockpit 与 OpenClaw Gateway 均为 loopback-only，只能通过 SSH 本地端口转发访问。
