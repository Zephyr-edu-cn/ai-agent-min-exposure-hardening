# Public Release Checklist

This project can be published as a sanitized engineering-security validation project, but raw local evidence should stay private.

## Safe To Publish

- `README.md`
- `architecture/`
- `config-snippets/` after confirming all tokens and account identifiers are redacted
- `scripts/`
- `screenshots-public-redacted/`
- `risk-analysis.md`
- `参考资料.md`
- `report.md`
- `evidence-package/tests/`
- `evidence-package/evidence-index.md` if raw paths are kept as references only

## Keep Private

- `report-outline.md`
- `report-draft.md`
- `_private/`
- `screenshots-redacted/`
- `evidence-package/raw/`
- `resume-materials/`
- course/private `.docx` files
- any real SSH private key, token, API key, `.env`, `openclaw.json`, or generated local config containing secrets

## Final Manual Check

- Search the repository for real token/API key/private key patterns before publishing.
- Ensure screenshots do not show personal email, Tailnet name, complete IPs, Windows user path, private key filename, or real account names.
- Keep the project description engineering-oriented: do not claim a new research method; describe it as a reproducible minimum-exposure deployment and boundary-validation project.

## Resume Use

For resume materials, cite the project as:

> 自托管智能体应用的最小暴露面部署与安全边界验证

Recommended keywords:

- Linux / OpenSSH / UFW / Fail2ban / Tailscale / Cockpit / OpenClaw / systemd
- minimum exposure
- account isolation
- public-key authentication
- loopback-only Gateway
- success/failure access testing
- reproducible evidence package
