# Runbook

## URLs & health

| What | URL |
|---|---|
| UI | https://kb.sathwiksangeethamproject.dev |
| API health | https://api.sathwiksangeethamproject.dev/api/v1/health |
| Health via UI proxy | https://kb.sathwiksangeethamproject.dev/api/v1/health |

## Deploy

Push to `main`. The pipeline (`.github/workflows/deploy.yml`) runs
RSpec + zeitwerk + lint + security scans, builds both arm64 images, pushes to
ECR, rolls the EC2 host via SSM, and verifies the public endpoints.
Manual run: Actions → deploy → Run workflow.

There is no SSH. All host access is via SSM:

```bash
aws ssm start-session --target i-0f862e6a8a78d505a          # interactive shell
aws ssm send-command --instance-ids i-0f862e6a8a78d505a \
  --document-name AWS-RunShellScript \
  --parameters 'commands=["cd /opt/portfolio && docker compose ps"]'
```

## Common operations (on the host, `cd /opt/portfolio`)

```bash
docker compose ps                                  # stack state
docker logs -f portfolio-kb-api                    # API logs
docker logs -f portfolio-kb-ui                     # UI logs
docker compose exec knowledge-base-api bin/rails c # Rails console
docker compose restart knowledge-base-api          # bounce API
```

## Databases

Four production DBs on the shared Postgres container:
`knowledge_base_api_production{,_cache,_queue,_cable}`, role `knowledge_base_api`.
Migrations run automatically on deploy (image entrypoint `db:prepare`).
If a *new* secondary schema is ever added, load it once with
`bin/rails db:schema:load:<name>` (guarded by `DISABLE_DATABASE_ENVIRONMENT_CHECK=1`).

## Secrets

Host `.env` at `/opt/portfolio/.env`, materialized from SSM Parameter Store
`/portfolio/env` (SecureString). Keys used by this app:
`KB_DB_PASSWORD`, `KB_RAILS_MASTER_KEY`, `KB_API_JWT_SECRET`.
Rotate by updating the parameter, re-materializing the file, and
`docker compose up -d knowledge-base-api knowledge-base-ui`.

## Failure playbook

| Symptom | First moves |
|---|---|
| 502 from Caddy | `docker compose ps` — container down/unhealthy; check `docker logs` |
| API healthy, UI 500 on `/api/*` | UI rewrite proxy — confirm kb-api resolves and the image was built with `NEXT_PUBLIC_API_URL=http://knowledge-base-api:80` |
| AI answers hang | `docker exec portfolio-ollama ollama ps` — model loading on 2GB host can take ~15s cold; sustained hangs → check host memory/swap |
| Deploy verify step fails | Roll succeeded but endpoint unhealthy — check container logs, then re-run workflow after fix |
