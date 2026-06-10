# Boundary Verification Workflow

This document summarizes how the public evidence package verifies the minimum-exposure deployment boundary of the self-hosted AI agent service.

The goal is not to benchmark model quality. The goal is to verify that management interfaces, SSH access, service accounts, firewall rules, Tailscale access control, and gateway authentication behave as expected under both allowed and denied access paths.

## 1. Verification Scope

The verification workflow covers the following boundaries:

- Identity boundary: non-root service account, SSH key authentication, disabled password login, and group-based access.
- Network boundary: UFW allow/deny rules, Tailscale access path, and non-exposed management interfaces.
- Service boundary: OpenClaw and management services bound to loopback or restricted interfaces.
- Gateway boundary: token-protected access to the AI agent gateway.
- Abuse-control boundary: Fail2Ban response to repeated failed login attempts.
- Evidence boundary: public evidence is sanitized; raw outputs and private screenshots remain local-only.

## 2. Preconditions

Before running the checks, ensure that:

- The target host has the hardening configuration applied.
- SSH public-key authentication is configured for the intended operator account.
- Password login and root login are disabled in the SSH configuration.
- UFW and Tailscale ACL rules are active.
- OpenClaw and related management interfaces are configured according to the public config snippets.
- Raw command outputs are collected locally and sanitized before publication.

Relevant public files:

- config-snippets/
- scripts/check-server-state.sh
- scripts/check-access-matrix.ps1
- evidence-package/evidence-index.md

## 3. Server-Side State Checks

Run the server-side state checker on the target host:

    bash scripts/check-server-state.sh

Expected checks include:

- SSH configuration status.
- Listening ports and local-only services.
- UFW status and exposed ports.
- Fail2Ban service status.
- OpenClaw-related service status.
- Tailscale connectivity and address state.

The raw output should be stored only in a private local evidence directory. Public excerpts must be sanitized before being referenced in reports.

## 4. Client-Side Access Matrix Checks

Run the access matrix checker from the Windows client side:

    powershell -ExecutionPolicy Bypass -File .\scripts\check-access-matrix.ps1

The check should distinguish expected successes from expected denials.

Typical expected results:

| Check | Expected result | Purpose |
|---|---:|---|
| SSH with valid key | PASS | Confirms authorized operator access |
| SSH password login | FAIL / denied | Confirms password login is disabled |
| Root SSH login | FAIL / denied | Confirms root login is disabled |
| Direct access to restricted services | FAIL / denied | Confirms management interfaces are not directly exposed |
| SSH tunnel access to loopback service | PASS | Confirms controlled administrative access path |
| Gateway request without token | FAIL / denied | Confirms gateway authentication boundary |
| Gateway request with valid token | PASS | Confirms intended authenticated access |
| Tailscale-only access path | PASS where allowed | Confirms private overlay access path |
| Unauthorized overlay or non-ACL path | FAIL / denied | Confirms ACL restriction |

## 5. Evidence Mapping

The public evidence package maps verification goals to sanitized evidence files.

Important references:

- evidence-package/tests/final-hardening-review.md
- evidence-package/tests/access-matrix.md
- evidence-package/tests/windows-ssh-client-alias.md
- evidence-package/evidence-index.md
- risk-analysis.md
- report.md

The review evidence should be read as a boundary-validation matrix, not as a claim of complete enterprise-grade security.

## 6. Pass / Warn / Fail Interpretation

Use the following interpretation rules:

- PASS: the boundary behaves as designed.
- WARN: the boundary is acceptable for the prototype but has a known limitation or operational dependency.
- FAIL: the boundary does not match the expected security posture and requires remediation before public reporting.

Examples:

- SSH key login working is a PASS.
- Password SSH login being rejected is a PASS.
- A loopback-only service being accessible only through an SSH tunnel is a PASS.
- A tokenless gateway request being rejected is a PASS.
- A public screenshot containing real addresses, key filenames, account names, or host identifiers is a FAIL and must be redacted.

## 7. Residual Risks

This workflow does not claim to eliminate all risk. Remaining risks include:

- Misconfiguration after system updates.
- Operator mistakes during SSH key or token rotation.
- Incomplete detection of all exposed services.
- Insufficient monitoring for application-layer abuse.
- Public evidence accidentally containing sensitive host, path, address, or account information.

These risks are tracked in risk-analysis.md.

## 8. Public Release Rules

Before publishing or updating the repository:

- Do not commit SSH private keys.
- Do not commit environment files, gateway tokens, API keys, or generated local configs.
- Do not commit raw evidence outputs.
- Do not commit unredacted screenshots.
- Prefer sanitized excerpts and summarized evidence.
- Re-run public grep checks before pushing.

## 9. Positioning

This repository documents a minimum-exposure hardening and verification workflow for a self-hosted AI agent service. It is not a full enterprise security platform, vulnerability scanner, SIEM system, or formal compliance audit.
