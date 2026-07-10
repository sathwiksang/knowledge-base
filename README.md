# Knowledge Base AI

Enterprise knowledge management platform with semantic search, a RAG (retrieval-augmented generation) pipeline, AI-powered Q&A, and real-time document processing.

**Live demo:** https://kb.sathwiksangeethamproject.dev

## Architecture

```
┌────────────┐     ┌─────────────────┐     ┌──────────────────────┐
│  Next.js UI │ ──► │  Rails 8 API     │ ──► │ PostgreSQL 17         │
│  (ui/)      │     │  (api/)          │     │ + pgvector embeddings │
└────────────┘     │  + Solid Queue   │     └──────────────────────┘
                   │    worker        │ ──► Ollama (LLM + embeddings)
                   └─────────────────┘
```

| Component | Path | Stack |
|---|---|---|
| API | [`api/`](api/) | Ruby on Rails 8 (API mode), PostgreSQL + pgvector, Solid Queue, JWT auth |
| UI | [`ui/`](ui/) | Next.js, TypeScript, Tailwind CSS |
| AI | — | Ollama — `llama3.2:3b` for generation, `nomic-embed-text` for embeddings |

## Local development

```bash
# API
cd api && bundle install && bin/rails db:setup && bin/dev

# UI
cd ui && npm install && npm run dev
```

See `api/.env.example` for required environment variables. Rails encrypted
credentials require `api/config/master.key` (not committed — stored securely
outside the repo).

## Deployment

Runs as containers orchestrated by [portfolio-platform](https://github.com/sathwiksang/portfolio-platform)
on AWS EC2, published through a Cloudflare Tunnel.
