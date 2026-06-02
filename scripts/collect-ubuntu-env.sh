#!/usr/bin/env bash
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT_DIR="$ROOT/evidence-package/raw"
OUT="$OUT_DIR/ubuntu-env.txt"
mkdir -p "$OUT_DIR"

section() {
  {
    echo
    printf '=%.0s' {1..80}
    echo
    echo "$1"
    printf '=%.0s' {1..80}
    echo
  } >> "$OUT"
}

run() {
  local name="$1"
  shift
  section "$name"
  {
    "$@" 2>&1 || true
  } >> "$OUT"
}

printf 'Collected at: %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" > "$OUT"

run "Ubuntu release" lsb_release -a
run "Hostname" hostnamectl
run "Kernel" uname -a
run "Current user" id
run "Groups: current user" groups
run "Network addresses" ip -br addr
run "Routes" ip route
run "SSH client" ssh -V
run "OpenSSH server status" systemctl status ssh --no-pager
run "OpenSSH effective config check" sudo sshd -t
run "Listening TCP/UDP sockets" ss -tulpn
run "UFW verbose status" sudo ufw status verbose
run "Fail2ban sshd status" sudo fail2ban-client status sshd
run "Tailscale status" tailscale status
run "Tailscale IPv4" tailscale ip -4
run "Node.js" node -v
run "npm" npm -v

echo "Wrote $OUT"
