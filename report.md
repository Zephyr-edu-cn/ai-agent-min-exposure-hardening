# 大模型智能体应用的最小暴露面部署与安全边界验证

## 摘要

本实验面向自托管大模型智能体应用的安全部署场景，围绕 Ubuntu Server、OpenSSH、UFW、Fail2Ban、Tailscale、Cockpit、OpenClaw Gateway 和 systemd 构建最小暴露面访问架构。实验不以模型调用效果为主要目标，而以管理面、Agent Gateway、远程登录和服务账号的安全边界为核心对象。系统通过账号隔离、SSH 公钥认证、禁用密码与 root 登录、管理员组限制、防火墙默认拒绝入站、Tailscale 私有访问控制、Cockpit 与 OpenClaw Gateway loopback-only 部署等措施，降低未授权访问、凭据泄露和管理面暴露风险。实验同时设计成功访问与失败访问矩阵，验证只有预期主体能够通过预期路径访问服务，绕过 SSH 隧道或私有访问路径的直连请求均失败。最终核查未发现硬性 `FAIL`，剩余项作为工程权衡和后续改进纳入风险分析。

关键词：大模型智能体；最小暴露面；OpenSSH；UFW；Tailscale；OpenClaw Gateway；安全边界验证

## 1. 实验背景与目标

大模型智能体应用通常不仅提供普通 Web 服务能力，还可能连接文件系统、命令执行、外部 API、浏览器或其他工具。相较传统 Web 应用，Agent 系统的风险不只来自端口暴露和弱认证，也来自工具调用边界、凭据管理、提示注入和间接提示注入等问题。OWASP LLM Top 10 与 Agentic AI 风险资料均提示，LLM 应用需要关注敏感信息泄露、过度代理、供应链和工具调用等风险；AgentDojo、InjecAgent 以及间接提示注入相关研究也说明，工具集成型 Agent 在处理不可信输入时存在系统性攻击面 [11]-[15]。

基于上述背景，本实验将目标限定为工程部署层面的安全边界验证：在个人虚拟机环境中部署 OpenClaw Gateway 与 Web 管理面，要求服务能够正常管理和访问，但不直接暴露到不可信网络。实验采用“不因网络位置默认信任”的访问控制思想 [1]，通过 OpenSSH、UFW、Tailscale 和 loopback-only 服务监听实现访问路径收敛。

本实验的具体目标包括：

- 验证 OpenSSH 只允许公钥认证，禁用密码认证、交互认证、空密码和 root 远程登录。
- 使用 `AllowGroups ssh-admins` 将 SSH 登录限制在管理员组内。
- 关闭 SSH Agent Forwarding，仅保留必要的 local port forwarding。
- 使用 UFW 默认拒绝入站，仅开放必要 SSH 入口。
- 使用 Tailscale ACL/Grants 将私有访问路径限制到指定客户端访问服务器 `tcp:22`。
- 将 Cockpit 与 OpenClaw Gateway 限制为 loopback-only，外部访问必须经过 SSH 隧道或受控私有网络路径。
- 启用 Fail2Ban 保护 `sshd`，并形成可复查的证据包。
- 通过成功/失败访问矩阵证明安全边界有效。

## 2. 实验环境

实验环境如下表所示。公开报告和仓库中不展示真实 IP、Tailnet 名称、完整设备名、账号邮箱、token、API Key 和 SSH 私钥路径。

| 项目 | 配置 |
|---|---|
| 客户端系统 | Windows，OpenSSH_for_Windows_9.5p2 |
| 虚拟化环境 | VMware Workstation NAT |
| 服务器系统 | Ubuntu Server 24.04.4 LTS |
| 服务器主机名 | `agent-secure` |
| VMware NAT IP | `<ubuntu-vm-nat-ip>` |
| Tailscale Windows IP | `<windows-tailscale-ip>` |
| Tailscale Ubuntu IP | `<ubuntu-tailscale-ip>` |
| 远程管理账号 | `deploy` |
| OpenClaw 服务账号 | `openclaw` |
| OpenClaw 版本 | `OpenClaw 2026.5.28 (e932160)` |

Ubuntu 24.04 LTS 属于当前长期支持版本，适合作为安全部署实验环境 [7]。实验未启用公网入口，也未启用 Tailscale Funnel。Tailscale 仅作为私有访问控制路径，OpenClaw Gateway 与 Cockpit 均不直接监听 NAT/Tailnet 地址。

## 3. 威胁模型与设计原则

本实验假设局域网和 Tailnet 均不天然可信。潜在威胁包括：

- 局域网中存在被感染主机，对 SSH、Cockpit 或 OpenClaw Gateway 端口进行扫描。
- SSH 弱口令、root 登录或非授权用户登录导致服务器失陷。
- Web 管理面暴露后，被攻击者用于修改系统用户、服务或配置。
- OpenClaw Gateway 暴露后，被攻击者调用工具、读取文件或触发越权动作。
- OpenClaw token、模型 API Key、SSH 私钥路径等敏感信息进入截图、报告或公开仓库。
- 不可信输入或间接提示注入诱导 Agent 调用高风险工具。
- Tailnet 默认放行策略导致私有网络内横向访问。

对应的设计原则为：

- 最小暴露面：除必要 SSH 管理入口外，不暴露 Web 管理面和 Agent Gateway。
- 最小权限：区分远程管理账号和服务账号，避免应用账号承担系统管理职责。
- 强身份认证：SSH 使用公钥认证，禁用密码、空密码和 root 远程登录。
- 路径可控：管理面访问必须经过 SSH local port forwarding 或受控 Tailscale 策略。
- 失败可验证：不仅验证服务能访问，也验证绕过预期路径时访问失败。
- 证据可复查：保留配置片段、命令输出、截图和脚本化验证结果。

## 4. 系统架构

系统访问路径如下：

```text
Windows Client
  |-- OpenSSH public key
  |-- Tailscale private network
  |-- SSH local port forwarding
  v
Ubuntu Server: agent-secure
  |-- sshd: tailscale0:22 and VMware host emergency path
  |-- Cockpit: 127.0.0.1:9090 / [::1]:9090 only
  |-- OpenClaw Gateway: 127.0.0.1:18789 / [::1]:18789 only
  |-- UFW: default deny incoming
  |-- Fail2Ban: sshd jail enabled
```

架构图源文件为 `architecture/minimal-exposure-architecture.mmd`。架构中不开放公网入口，不启用 Tailscale Funnel；Cockpit 与 OpenClaw Gateway 均为 loopback-only；外部管理访问通过 SSH local port forwarding 完成。

## 5. 关键实现

### 5.1 账号与权限隔离

实验中使用 `deploy` 作为远程管理账号，加入 `ssh-admins` 组；使用 `openclaw` 作为 OpenClaw 服务账号，仅负责运行 OpenClaw Gateway，不加入 `sudo` 或 `ssh-admins`。这样即使 OpenClaw 服务侧出现配置错误或应用层风险，服务账号也不会天然获得 SSH 管理入口或系统管理员权限。

该设计属于最小权限原则的工程实践。相关证据保存在 `evidence-package/tests/final-hardening-review.md`、`evidence-package/raw/10-server-state.txt` 和公开脱敏截图中。

### 5.2 OpenSSH 加固

OpenSSH 是本实验的主要远程入口，因此使用 `sshd -T` 核查 effective configuration。最终状态包括：

```text
pubkeyauthentication yes
passwordauthentication no
kbdinteractiveauthentication no
permitemptypasswords no
permitrootlogin no
allowgroups ssh-admins
allowagentforwarding no
allowtcpforwarding local
gatewayports no
maxauthtries 3
loglevel VERBOSE
```

其中，`PasswordAuthentication no`、`KbdInteractiveAuthentication no` 和 `PermitEmptyPasswords no` 用于避免口令路径；`PermitRootLogin no` 用于禁止 root 远程登录；`AllowGroups ssh-admins` 将 SSH 登录主体限制在管理员组；`AllowAgentForwarding no` 避免本地 agent 被远程主机滥用；`AllowTcpForwarding local` 和 `GatewayPorts no` 只保留本实验需要的本地端口转发，不允许远端开放转发端口。上述配置项依据 OpenSSH `sshd_config(5)` 文档进行解释 [2]。

证据材料包括 `config-snippets/sshd-hardening.conf`、`screenshots-public-redacted/01_sshd_T_effective_config.png` 和 `evidence-package/tests/final-hardening-review.md`。

Windows 客户端已在 `~/.ssh/config` 中设置 `agent-secure`（Tailnet 主路径）与 `agent-secure-nat`（VMware NAT 应急路径）两个主机别名，固定 `User deploy` 和专用 `IdentityFile`，并设置 `IdentitiesOnly yes`、`ForwardAgent no`。脱敏后的配置、`ssh -G` 解析结果与现场登录复测见 `evidence-package/tests/windows-ssh-client-alias.md`。

### 5.3 UFW、Tailscale 与 Fail2Ban

UFW 采用默认拒绝入站策略，仅允许必要 SSH 入口。Tailscale ACL/Grants 限制为指定 Windows 客户端访问 Ubuntu 服务器 `tcp:22`，并在策略中禁用 Tailscale SSH，避免产生另一条独立登录控制面。UFW 和 Tailscale 的策略依据分别参考 Ubuntu UFW 文档与 Tailscale ACL/Policy syntax 文档 [4]-[6]。

Fail2Ban 启用 `sshd` jail，用于记录和限制认证失败行为。虽然 SSH 已禁用密码登录，Fail2Ban 仍可作为审计和防御性加固手段。

当前保留 VMware NAT 宿主机到 SSH 的应急管理路径。这不是公网暴露，而是实验环境中的工程权衡。主要远程访问路径是 Tailscale 私有网络和 OpenSSH 公钥认证；在更严格的最终演示环境中，可以删除 VMware NAT 应急规则，仅保留 Tailscale 入口。

### 5.4 Cockpit 管理面控制

Cockpit 作为 Web 管理面，具备系统状态查看和管理能力，因此不直接暴露到 NAT 或 Tailnet 地址。最终监听状态为 loopback-only：

```text
127.0.0.1:9090
[::1]:9090
```

访问 Cockpit 时，客户端通过 SSH local port forwarding 将本地端口转发到服务器 `127.0.0.1:9090`。实验验证 NAT/Tailnet 地址直连 Cockpit 失败，而 SSH tunnel 访问成功。该策略符合管理面不直接暴露给不可信网络的原则。

### 5.5 OpenClaw Gateway 控制

OpenClaw Gateway 由 systemd 服务持久化运行，监听地址限制为：

```text
127.0.0.1:18789
[::1]:18789
```

Gateway 侧启用 token 认证，并关闭直接 Tailscale 暴露选项。客户端访问时使用 SSH local port forwarding，将本地端口映射到服务器 loopback Gateway。未带 token 或 scope 不足的请求会被拒绝，实验中观察到 `token_missing` 和 `missing scope: operator.read` 等拒绝结果。

OpenClaw audit 最终结果为 `0 critical · 2 warn · 1 info`。其中 `gateway.trusted_proxies_missing` 在当前 loopback-only、无反向代理架构下不构成直接暴露；`gateway.probe_failed` 的 `missing scope: operator.read` 表明探针未获得操作员读取权限。审计同时显示 `tools.elevated` 与 `browser control` 仍处于 enabled 状态，因此在实际接入模型前仍需关闭非必要能力或配置显式 allowlist。

## 6. 验证方法与结果

实验采用成功访问和失败访问组合验证。仅证明“能访问”不足以说明部署安全；本实验重点证明绕过受控路径时访问失败。

| 测试项 | 预期结果 | 实际结果 |
|---|---|---|
| `deploy` 公钥登录 | 成功 | 成功 |
| `deploy` 密码登录 | 失败 | `Permission denied (publickey)` |
| `root` 登录 | 失败 | `Permission denied (publickey)` |
| OpenSSH via Tailnet | 成功 | 成功 |
| NAT 应急 SSH | 成功 | 成功 |
| NAT 直连 Cockpit | 失败 | 失败 |
| Tailnet 直连 Cockpit | 失败 | 失败 |
| Cockpit via SSH tunnel | 成功 | 成功 |
| NAT 直连 OpenClaw Gateway | 失败 | 失败 |
| Tailnet 直连 OpenClaw Gateway | 失败 | 失败 |
| OpenClaw Gateway via SSH tunnel | 成功 | 成功 |
| OpenClaw no-token request | 失败 | `token_missing` |
| OpenClaw insufficient scope | 失败 | `missing scope: operator.read` |
| OpenClaw systemd after reboot | 保持运行 | `enabled` / `active` |

端口监听检查显示，Cockpit 与 OpenClaw Gateway 未监听 `0.0.0.0`，只监听 loopback。UFW 状态显示默认拒绝入站，Fail2Ban 状态显示 `sshd` jail 启用。上述证据对应 `screenshots-public-redacted/` 中的截图和 `evidence-package/tests/` 中的核查文件。

## 7. 最终核查结果

按照 PASS / WARN / FAIL 标准，最终核查结果如下。

PASS：

- OpenSSH 公钥认证启用。
- PasswordAuthentication、KbdInteractiveAuthentication、PermitEmptyPasswords 均关闭。
- PermitRootLogin 为 `no`。
- 使用 `AllowGroups ssh-admins` 限制管理员登录组。
- `AllowAgentForwarding no`，`AllowTcpForwarding local`，`GatewayPorts no`。
- UFW 默认拒绝入站，并只保留必要 SSH 入口。
- Tailscale ACL/Grants 仅允许指定客户端访问服务器 `tcp:22`。
- Fail2Ban `sshd` jail 启用。
- Cockpit 和 OpenClaw Gateway 均为 loopback-only。
- 成功/失败访问矩阵验证通过。

WARN：

- SSH 仍监听 `0.0.0.0:22`。这是保留 VMware NAT / Tailnet 管理入口的工程权衡，实际访问由 UFW、Tailscale、公钥认证、禁 root、AllowGroups 和 Fail2Ban 多层收敛。
- Tailscale ACL/Grants 属于云端控制面配置，需要以脱敏截图或策略摘要作为报告证据。
- OpenClaw audit 存在 2 项 warning，当前作为剩余风险记录，不影响“管理面和 Gateway 不直接暴露到不可信网络”的核心目标。

FAIL：

- 最终核查未发现硬性 `FAIL`。

## 8. 剩余风险与后续改进

本实验不声称消除所有 Agent 安全风险。剩余风险包括：

- OpenClaw token 仍属于 secret-bearing config，后续可迁移到 OpenClaw SecretRefs、系统级 secret store 或受限环境文件。
- 实验中未配置真实模型 API Key，避免凭据进入截图和报告；若后续验证模型调用，应使用最小权限 Key 并限制读取权限。
- Cockpit 登录后仍可能具备系统管理能力，后续可限制模块、增强二次认证或仅用于状态查看。
- OpenClaw 工具调用仍可能带来文件读写、命令执行和提示注入风险，后续应最小化 enabled tools、限制工作目录、增加人工确认和工具调用日志审计。
- VMware NAT 应急 SSH 可在最终演示环境中关闭，只保留 Tailscale 私有访问路径。

## 9. 实验结论

本实验围绕自托管大模型智能体应用完成了一个可验证的最小暴露面部署方案。系统从账号、认证、网络、服务和验证五个层面收敛访问边界：使用 `deploy` 与 `openclaw` 账号隔离降低权限耦合；使用 OpenSSH 公钥认证、禁密码、禁 root 和 `AllowGroups` 收敛远程登录主体；使用 UFW、Tailscale ACL/Grants 和 Fail2Ban 控制 SSH 访问路径；将 Cockpit 与 OpenClaw Gateway 限制为 loopback-only；通过 SSH tunnel、端口监听检查和成功/失败访问矩阵验证服务未直接暴露到不可信网络。

因此，本实验的核心成果不是“部署了一个可访问的 Agent 服务”，而是形成了包含配置片段、截图、脚本、架构图、风险分析和参考资料的证据链，证明系统满足“只有预期主体能通过预期路径访问”的工程安全目标。该实践可作为自托管智能体应用在部署安全、访问边界验证和配置证据链管理方面的工程案例。

## 参考文献

[1] ROSE S, BORCHERT O, MITCHELL S, CONNELLY S. Zero Trust Architecture: NIST Special Publication 800-207[S/OL]. Gaithersburg: National Institute of Standards and Technology, 2020[2026-06-01]. https://doi.org/10.6028/NIST.SP.800-207.

[2] OpenBSD. sshd_config(5): OpenSSH daemon configuration file[EB/OL]. [2026-06-01]. https://man.openbsd.org/sshd_config.

[3] OpenSSH. OpenSSH 8.2 release notes[EB/OL]. 2020[2026-06-01]. https://www.openssh.com/txt/release-8.2.

[4] Tailscale. Manage permissions using ACLs[EB/OL]. [2026-06-01]. https://tailscale.com/kb/1018/acls.

[5] Tailscale. Syntax reference for the tailnet policy file[EB/OL]. [2026-06-01]. https://tailscale.com/kb/1337/policy-syntax.

[6] Ubuntu Documentation. UFW - Uncomplicated Firewall[EB/OL]. [2026-06-01]. https://help.ubuntu.com/community/UFW.

[7] Ubuntu. Ubuntu release cycle[EB/OL]. [2026-06-01]. https://ubuntu.com/about/release-cycle.

[8] Cockpit Project. Running Cockpit[EB/OL]. [2026-06-01]. https://cockpit-project.org/running.html.

[9] systemd. systemd.exec(5): Execution environment configuration[EB/OL]. [2026-06-01]. https://www.freedesktop.org/software/systemd/man/latest/systemd.exec.html.

[10] Fail2Ban contributors. Fail2Ban: ban hosts that cause multiple authentication errors[EB/OL]. [2026-06-01]. https://github.com/fail2ban/fail2ban.

[11] OWASP Foundation. OWASP Top 10 for LLM Applications 2025[EB/OL]. 2024[2026-06-01]. https://genai.owasp.org/resource/owasp-top-10-for-llm-applications-2025/.

[12] OWASP Foundation. Agentic AI - Threats and Mitigations[EB/OL]. 2025[2026-06-01]. https://genai.owasp.org/resource/agentic-ai-threats-and-mitigations/.

[13] DEBENEDETTI E, ZHANG J, BALUNOVIC M, BEURER-KELLNER L, FISCHER M, TRAMER F. AgentDojo: A Dynamic Environment to Evaluate Prompt Injection Attacks and Defenses for LLM Agents[C]//Advances in Neural Information Processing Systems 37. NeurIPS, 2024[2026-06-01]. https://proceedings.neurips.cc/paper_files/paper/2024/hash/97091a5177d8dc64b1da8bf3e1f6fb54-Abstract-Datasets_and_Benchmarks_Track.html.

[14] ZHAN Q, LIANG Z, YING Z, KANG D. InjecAgent: Benchmarking Indirect Prompt Injections in Tool-Integrated Large Language Model Agents[C]//Findings of the Association for Computational Linguistics: ACL 2024. Bangkok: Association for Computational Linguistics, 2024: 10471-10506[2026-06-01]. https://aclanthology.org/2024.findings-acl.624/.

[15] ABDELNABI S, GRESHAKE K, MISHRA S, ENDRES C, HOLZ T, FRITZ M. Not What You've Signed Up For: Compromising Real-World LLM-Integrated Applications with Indirect Prompt Injection[C]//Proceedings of the 16th ACM Workshop on Artificial Intelligence and Security. Copenhagen: ACM, 2023: 79-90[2026-06-01]. https://doi.org/10.1145/3605764.3623985.

[16] OpenClaw. Remote access[EB/OL]. [2026-06-01]. https://docs.openclaw.ai/gateway/remote.

[17] OpenClaw. Security[EB/OL]. [2026-06-01]. https://docs.openclaw.ai/gateway/security.
