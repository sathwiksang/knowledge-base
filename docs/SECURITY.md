# Security posture

## Boundaries

- **No inbound ports** except Caddy's 80/443 on the host; the EC2 security
  group exposes nothing else. Host administration is SSM-only (no SSH keys).
- **TLS** terminates at Caddy (Let's Encrypt, auto-renewed). Rails runs with
  `assume_ssl` + `force_ssl`; HSTS is emitted by the UI's middleware.
- **Same-origin browser traffic**: the UI proxies `/api/*` server-side, so no
  CORS surface is exposed to browsers; the API's CORS allowlist exists only
  for direct API consumers and defaults to the product hostnames.

## Application

- JWT-based auth between UI and API (`JWT_SECRET_KEY`, 96-hex-char secret).
- Rails host authorization allowlist (public hostnames + internal service name).
- CSP on the UI: `default-src 'self'`, `frame-ancestors 'none'`; X-Frame-Options DENY.
- Encrypted Rails credentials; `master.key` never committed — injected as
  `RAILS_MASTER_KEY` from SSM-backed host env.
- Dedicated DB role per app on the shared Postgres instance.

## Pipeline

- Brakeman static analysis + bundler-audit (gem CVEs) + `npm audit` run on
  every push (`security` job). **Currently informational** — the uplift
  backlog is to triage findings and flip them to blocking.
- Dependabot: weekly bundler (api), npm (ui), and GitHub Actions updates.
- Deploys authenticate via GitHub OIDC → `portfolio-github-deploy` IAM role
  (scoped: ECR `portfolio/*` push + SSM to the one host; deletion actions denied).

## Known gaps (uplift backlog)

1. Make Brakeman/bundler-audit/npm-audit blocking after triage.
2. Rate limiting (rack-attack) on auth + upload endpoints.
3. ESLint purity errors in the UI (`ci-ui` lint step is informational).
4. Backups: Postgres volume snapshot cadence (currently EBS-snapshot-on-change only).
