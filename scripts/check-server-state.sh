#!/usr/bin/env bash
set -u

section() {
  echo
  printf '=%.0s' {1..80}
  echo
  echo "$1"
  printf '=%.0s' {1..80}
  echo
}

run() {
  local name="$1"
  shift
  section "$name"
  "$@" 2>&1 || true
}

echo "Server state regression check"
echo "Collected at: $(date '+%Y-%m-%d %H:%M:%S %Z')"
sudo -v 2>/dev/null || true

run "System release" lsb_release -a
run "Hostname" hostnamectl
run "Network addresses" ip -br addr
run "Routes" ip route

run "Account boundary: deploy" id deploy
run "Account boundary: openclaw" id openclaw
run "Groups: deploy" groups deploy
run "Groups: openclaw" groups openclaw

section "OpenSSH effective hardening"
sudo -n /usr/sbin/sshd -T 2>/dev/null | grep -E '^(passwordauthentication|kbdinteractiveauthentication|permitemptypasswords|permitrootlogin|pubkeyauthentication|allowgroups|allowusers|allowagentforwarding|allowtcpforwarding|x11forwarding|gatewayports|maxauthtries|loglevel)\b' || \
  /usr/sbin/sshd -T 2>&1 | grep -E '^(passwordauthentication|kbdinteractiveauthentication|permitemptypasswords|permitrootlogin|pubkeyauthentication|allowgroups|allowusers|allowagentforwarding|allowtcpforwarding|x11forwarding|gatewayports|maxauthtries|loglevel)\b' || true

run "OpenSSH service" systemctl status ssh --no-pager
run "OpenSSH hardening snippet" cat /etc/ssh/sshd_config.d/00-agent-lab-hardening.conf

run "UFW status" sudo ufw status verbose

run "Tailscale version" tailscale version
run "Tailscale IPv4" tailscale ip -4
run "Tailscale status" tailscale status

run "Fail2ban status" sudo fail2ban-client status
run "Fail2ban sshd jail" sudo fail2ban-client status sshd

run "Cockpit socket status" systemctl status cockpit.socket --no-pager
run "Cockpit socket override" cat /etc/systemd/system/cockpit.socket.d/listen-local.conf

run "OpenClaw Gateway service enabled" systemctl is-enabled openclaw-gateway
run "OpenClaw Gateway service active" systemctl is-active openclaw-gateway
run "OpenClaw Gateway status" systemctl status openclaw-gateway --no-pager
run "OpenClaw Gateway service file" cat /etc/systemd/system/openclaw-gateway.service

section "Listening sockets: ssh/cockpit/openclaw"
ss -tulpn 2>&1 | grep -E ':22|:9090|:18789' || true

section "OpenClaw account config permissions"
sudo -u openclaw -H bash -lc 'ls -ld ~/.openclaw; ls -l ~/.openclaw/openclaw.json 2>/dev/null || true'

section "OpenClaw security audit"
sudo -u openclaw -H bash -lc 'export PATH="$HOME/.openclaw/bin:$HOME/.openclaw/node/bin:$PATH"; openclaw security audit --deep' 2>&1 || true
