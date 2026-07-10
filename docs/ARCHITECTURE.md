# Architecture

## System overview

Knowledge Base AI is a two-service product: a Rails 8 API (API-only mode) and a
Next.js 16 UI, backed by PostgreSQL 17 with pgvector and a local Ollama runtime
for embeddings and generation. Everything runs as containers on a single AWS
EC2 host (Graviton/arm64), fronted by Caddy, which terminates TLS.

```
                       ┌──────────────────────── EC2 portfolio-host ────────────────────────┐
                       │                                                                     │
 Internet ── 443 ──►  Caddy ── kb.…​.dev ──► Next.js UI (:3000) ──┐                          │
                       │  └─ api.….dev ──► Rails API (:80) ◄──────┘ /api/* server-side proxy │
                       │                        │                                            │
                       │                        ├──► PostgreSQL 17 + pgvector                │
                       │                        │      primary / cache / queue / cable DBs   │
                       │                        └──► Ollama (nomic-embed-text, qwen2.5)      │
                       │       Solid Queue runs inside Puma (SOLID_QUEUE_IN_PUMA=true)       │
                       └─────────────────────────────────────────────────────────────────────┘
```

## Key decisions

| Decision | Rationale |
|---|---|
| UI proxies `/api/*` server-side (Next rewrites) | Browser stays same-origin: no CORS, no mixed content, CSP `connect-src 'self'` holds. The rewrite destination is baked at image build (`ARG NEXT_PUBLIC_API_URL`), because Next compiles rewrites into the routes manifest. |
| Solid Queue inside Puma | Saves a whole worker container (~250MB) on the 2GB host; job volume is demo-scale. Flip `SOLID_QUEUE_IN_PUMA` off and run `bin/jobs` in a separate service when volume grows. |
| Four Rails databases (primary/cache/queue/cable) | Rails 8 defaults; keeps cache/queue churn out of the primary's WAL. All live on the same Postgres instance. |
| Dedicated Postgres role `knowledge_base_api` | Blast-radius isolation from the other portfolio apps sharing the instance. Password comes from the host `.env` (sourced from SSM Parameter Store `/portfolio/env`). |
| Ollama with small models | `nomic-embed-text` for embeddings, `qwen2.5:0.5b` for generation — the largest models that respond interactively on a t4g.small. Model names are env-driven (`OLLAMA_LLM_MODEL`), so a host upgrade only needs an env change. |
| JWT auth between UI and API | `JWT_SECRET_KEY` from the host `.env`; tokens issued by the API, stored client-side. |

## Production topology

- Image registry: ECR `portfolio/kb-api`, `portfolio/kb-ui` (arm64, built by CI on `ubuntu-24.04-arm`).
- Host path: `/opt/portfolio` (compose project shared with the other portfolio apps — see
  [portfolio-platform](https://github.com/sathwiksang/portfolio-platform)).
- The API serves on container port 80 via Puma directly (Thruster is not in the bundle;
  Caddy already provides TLS, HTTP/2, and compression).
- Rails host authorization allows the public hostnames plus the internal
  service name (`RAILS_ADDITIONAL_HOSTS=knowledge-base-api`) used by the UI proxy.

## Data flow: document ingestion → answer

1. Upload hits the API; the document is chunked and queued (Solid Queue).
2. Worker threads embed chunks via Ollama `nomic-embed-text` → pgvector columns.
3. A question embeds the query, does cosine top-k over pgvector, and feeds
   retrieved chunks to the LLM for a grounded answer.
