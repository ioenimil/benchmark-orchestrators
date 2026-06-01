# Poly-Orchestrator Challenge — Application Tier

A four-service web application used to benchmark **AWS ECS Fargate** vs **Amazon EKS**. The same Docker images are deployed to both orchestrators without any changes.

---

## Architecture

```
Browser
  │
  ▼
┌─────────────────────────────────────────┐
│  frontend  (nginx :80 → :8080 public)  │
│  - serves React SPA (static)           │
│  - proxies /api/* → backend:8000       │
└────────────────┬────────────────────────┘
                 │ /api/* (internal)
                 ▼
┌─────────────────────────────────────────┐
│  backend  (FastAPI :8000, internal)    │
│  - CRUD for names                      │
│  - read-through Redis cache            │
│  - falls back to Postgres if Redis ↓   │
└───────┬──────────────────┬─────────────┘
        │                  │
        ▼                  ▼
┌──────────────┐   ┌──────────────────┐
│  postgres    │   │  redis           │
│  (system of  │   │  (disposable     │
│   record)    │   │   cache, no vol) │
└──────────────┘   └──────────────────┘
```

The browser **never** contacts the backend directly. All traffic enters through `frontend:80`.

---

## Quick start

```bash
# 1. copy env file
cp .env.example .env

# 2. build and start all services
docker compose up --build -d

# 3. open the app
open http://localhost:8080
```

To stop: `docker compose down`  
To stop and wipe data: `docker compose down -v`

---

## Environment variables

All configuration is injected at runtime — nothing is baked into images.

### `.env` (read by Compose for postgres + DATABASE_URL interpolation)

| Variable            | Example       | Used by                          |
|---------------------|---------------|----------------------------------|
| `POSTGRES_DB`       | `orchestrator`| postgres image, DATABASE_URL     |
| `POSTGRES_USER`     | `postgres`    | postgres image, DATABASE_URL     |
| `POSTGRES_PASSWORD` | `postgres`    | postgres image, DATABASE_URL     |

### Backend service env vars

| Variable       | Example                                              | Description                        |
|----------------|------------------------------------------------------|------------------------------------|
| `DATABASE_URL` | `postgresql+psycopg://postgres:postgres@postgres/...`| Full Postgres connection string    |
| `REDIS_HOST`   | `redis`                                              | Redis hostname                     |
| `REDIS_PORT`   | `6379`                                               | Redis port                         |

### Frontend service env vars

| Variable       | Example    | Description                             |
|----------------|------------|-----------------------------------------|
| `BACKEND_HOST` | `backend`  | Backend hostname (resolved by nginx)    |
| `BACKEND_PORT` | `8000`     | Backend port (resolved by nginx)        |

---

## API contract

Base URL (from browser): `http://localhost:8080/api`  
Base URL (internal): `http://backend:8000`

| Method   | Path          | Body                  | Success | Description                            |
|----------|---------------|-----------------------|---------|----------------------------------------|
| `GET`    | `/names`      | —                     | 200     | Array of `{id, name, created_at}`      |
| `POST`   | `/names`      | `{"name": "string"}`  | 201     | Created record; 422 if blank           |
| `DELETE` | `/names/{id}` | —                     | 204     | Deletes record; 404 if not found       |
| `GET`    | `/healthz`    | —                     | 200     | Liveness probe (always up)             |
| `GET`    | `/readyz`     | —                     | 200/503 | Readiness: checks Postgres + Redis     |

---

## Cache behaviour

The backend uses a **read-through cache** with Redis.

- **Key**: `names:all`
- **TTL**: 30 seconds
- **On `GET /names`**:
  - Cache HIT → return cached JSON (logged: `CACHE HIT`)
  - Cache MISS → query Postgres, store in Redis for 30 s, return (logged: `CACHE MISS`)
- **On `POST /names` or `DELETE /names/{id}`**: delete `names:all` so the next read repopulates.
- **Redis unavailable**: `GET /names` catches the `RedisError`, logs a WARNING, and queries Postgres directly. The endpoint **never** returns 5xx due to a Redis outage.

---

## Resiliency check

```bash
# 1. Confirm everything is healthy
curl -s localhost:8080/api/readyz          # {"status":"ok"}

# 2. Kill Redis
docker kill $(docker ps -qf "name=redis")

# 3. Names still load (Postgres fallback, warning in backend logs)
curl -s localhost:8080/api/names           # 200, returns names
docker compose logs backend | grep -i "redis"   # WARNING: Redis unavailable

# 4. Restart Redis and confirm full recovery
docker compose up -d redis
curl -s localhost:8080/api/readyz          # {"status":"ok"}
```

---

## Cloud-readiness notes

| Principle | How it's implemented |
|---|---|
| **Config via env vars** | Every hostname, port, credential, and URL is injected at runtime. Nothing is hardcoded. The same image works in Compose, ECS, and EKS — only the env vars change. |
| **Redis has no volume** | Redis is a disposable cache. Losing it loses only the cache (max 30 s stale read window), not data. In ECS/EKS, task replacements and restarts shouldn't carry cache state across. |
| **Seeding in app code** | The idempotent `seed()` runs in the FastAPI lifespan hook on startup. There's no mounted SQL init file that would be missing in ECS/EKS task definitions or Kubernetes pods. |
| **Health endpoints** | `/healthz` (liveness) always returns 200. `/readyz` (readiness) checks both Postgres and Redis, returning 503 until both are up. ECS and EKS use these for traffic management. |
| **0.0.0.0 binding** | uvicorn binds to `0.0.0.0:8000` so the container is reachable regardless of the network interface assigned by the orchestrator. |
| **Non-root images** | The backend runs as `appuser`. Minimal base images reduce attack surface. |
| **No VITE_BACKEND_URL** | The SPA calls relative `/api`. The backend hostname is resolved by nginx at runtime from `BACKEND_HOST`/`BACKEND_PORT` env vars, so the frontend image never needs to be rebuilt when moving between environments. |
