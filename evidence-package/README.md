# Evidence Package

这个目录用于保存可复现证据。所有截图、配置、命令输出都要脱敏：不要提交私钥、token、API Key、真实密码、完整公网 IP 或个人账号邮箱。

## 目录结构

```text
raw/
tests/
../architecture/
../config-snippets/
../screenshots-public-redacted/
```

## 最低证据清单

- Windows 环境：`scripts/collect-windows-env.ps1` 输出。
- Ubuntu 环境：`scripts/collect-ubuntu-env.sh` 输出。
- 架构图：展示 Windows、SSH、Tailscale、Ubuntu VM、Cockpit 与 OpenClaw Gateway。
- SSH 加固配置：`00-agent-lab-hardening.conf` 的脱敏片段。
- UFW 状态：`sudo ufw status verbose`。
- Tailscale 状态：`tailscale status` 和 `tailscale ip -4`。
- Fail2ban 状态：`sudo fail2ban-client status sshd`。
- 管理面监听地址：`ss -tulpn | grep 9090` 或对应端口。
- OpenClaw Gateway 监听地址：`ss -tulpn | grep 18789` 或对应端口。
- 成功访问截图：SSH 登录、SSH 隧道访问管理面、SSH 隧道访问 OpenClaw。
- 失败访问截图或命令输出：密码登录失败、root 登录失败、非授权用户失败、未通过隧道访问管理面失败、未通过隧道访问 OpenClaw 失败。

## 回归脚本

Windows 侧访问面回归：

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\check-access-matrix.ps1
```

输出：

```text
raw/09-access-matrix.txt
raw/09-access-matrix.json
```

Ubuntu 侧服务状态采集：

```bash
bash scripts/check-server-state.sh | tee evidence-package/raw/10-server-state.txt
```

报告引用脚本输出摘要，不粘贴敏感 token、API Key 或完整个人账号信息。

## 访问测试矩阵

最终 OpenSSH hardening 核查见：

```text
tests/final-hardening-review.md
```

最终访问矩阵见：

```text
tests/access-matrix.md
```

Windows SSH 客户端别名与现场复测见：

```text
tests/windows-ssh-client-alias.md
```

| 测试对象 | 测试内容 | 预期结果 | 实际结果 |
|---|---|---|---|
| SSH | `deploy` 公钥认证 | 成功 | 成功 |
| SSH | 密码登录 | 失败 | `Permission denied (publickey)` |
| SSH | root 登录 | 失败 | `Permission denied (publickey)` |
| UFW | 非必要入站端口 | 拒绝或不可达 | 9090 / 18789 直连失败 |
| Tailscale | 私有地址 SSH | 按 ACL 成功 | 成功 |
| Web 管理面 | 未经隧道直连 | 失败 | 失败 |
| Web 管理面 | SSH 隧道访问 | 成功 | 成功 |
| OpenClaw | 未经隧道直连 Gateway | 失败 | 失败 |
| OpenClaw | SSH 隧道访问 Gateway | 成功且需要认证 | 成功，未授权请求被拒绝 |
