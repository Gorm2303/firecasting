# Copilot instructions – firecasting (deployment)

## Project layout
- Docker Compose orchestration + Traefik reverse proxy (TLS termination)
- `deploy/dev/` — development compose stack (localhost certs, auto-compose.metrics.yml for monitoring)
- `deploy/prod/` — production stack (Let's Encrypt, hardened middlewares, watchtower auto-updates)
- Services: Traefik, Postgres, API (backend), Frontend (Vite app), optional Prometheus/Grafana/Loki/Promtail/Cadvisor

## Development: Docker Compose-first workflow
- **From `deploy/dev/` directory:**
  - `docker compose up --build` — builds backend + frontend from source, starts full stack
  - `docker compose logs -f api` — tail API logs
  - `docker compose logs -f frontend` — tail frontend logs
  - Edit code in IDE; re-run `up --build` to rebuild containers
- **Monitoring (optional):**
  - `docker compose -f compose.yml -f compose.metrics.yml up -d`
  - Adds Prometheus (scrapes /actuator/prometheus from API), Grafana, Loki, Promtail, Cadvisor, Blackbox
  - Grafana dashboard at `https://grafana.local.test` (admin/changeme)
- **Environment:**
  - `.env` file or inline: `FRONT_HOST=fire.local.test`, `API_HOST=api.local.test`, `DB_PASSWORD=devpass`
  - Traefik generates self-signed certs in `traefik/certs/`
  - Postgres runs in container with auto-compose volume `db-data`

## Networking & routing
- **Traefik labels** define routing rules per service
- **API:** routes `/api/*` by hostname; special SSE router (`/api/simulation/progress`) disables compression/buffering
  - Generic API router: applies gzip, rate limit, CORS
  - SSE router (priority 50): bypasses compression, sets `X-Accel-Buffering: no`, long timeouts
- **Frontend:** static site, routed by hostname
- **CORS:** both Traefik middleware (edge) and Spring (app-level) handle it
  - Middleware mirrors Spring config for preflight optimization

## Production: hardened stack
- **From `deploy/prod/` directory:**
  - `docker compose up -d` (assumes images are already built and pushed to registry, e.g., docker.io)
  - Let's Encrypt auto-provisioning: Traefik handles ACME challenge
  - HTTP → HTTPS redirect
- **SSL/TLS:** Let's Encrypt via ACME, renewed automatically
- **Security headers:** HSTS, frame-deny, X-Content-Type-Options, CSP, referrer policy
- **Rate limiting:** 50 req/s per IP, burst 100
- **Monitoring:** optional Prometheus + Loki + Grafana (behind compose `profiles: ["monitoring"]`)
- **Auto-updates:** Watchtower watches for new image tags, auto-deploys (configurable schedule)
- **DB:** no published ports; internal-only via Docker network

## Key configuration
- **Backend env vars (API service):**
  - `SPRING_PROFILES_ACTIVE=dev|prod`
  - `SPRING_DATASOURCE_URL=jdbc:postgresql://db:5432/appdb`
  - `SPRING_MVC_CORS_MAPPINGS_*` (dev) or `SPRING_WEB_CORS_*` (prod)
  - `MANAGEMENT_ENDPOINTS_WEB_EXPOSURE_INCLUDE=health,info,prometheus`
  - `SETTINGS_RUNS`, `SETTINGS_BATCH_SIZE`, `SETTINGS_TIMEOUT`
  - `SETTINGS_SSE_INTERVAL` (ms between SSE flushes)
- **Frontend env vars (frontend service):**
  - `VITE_API_BASE_URL=https://${API_HOST}/api/simulation` (with prefix)
- **Postgres:**
  - `POSTGRES_DB=appdb`, `POSTGRES_USER=appuser`, `POSTGRES_PASSWORD=${DB_PASSWORD}`
  - Volume: `db-data` (persistent across restarts)
  - Healthcheck: `pg_isready -U appuser -d appdb`
- **Traefik:**
  - `FRONT_HOST`, `API_HOST` — hostnames for routing
  - `LE_EMAIL` — Let's Encrypt contact email (prod only)
  - `DB_PASSWORD` — passed to all services securely

## Health checks
- **API:** GET `http://localhost:8080/actuator/health` → `{"status":"UP"}` or similar
- **Frontend:** GET `http://localhost:3000/` → 200 OK
- **Postgres:** `pg_isready -U appuser -d appdb`
- Docker Compose waits for service health before starting dependents (`depends_on: condition: service_healthy`)

## Monitoring stack (optional, `profiles: ["monitoring"]`)
- **Prometheus:** scrapes `/actuator/prometheus` from API and Traefik metrics
- **Grafana:** dashboard + alerting; provisioned with datasources & dashboards
- **Loki:** log aggregation from container logs and syslog
- **Promtail:** ships container logs to Loki
- **Cadvisor:** container resource metrics
- **Blackbox exporter:** endpoint health probes

## Conventions to preserve
- **Do not publish DB ports.** Postgres is internal-only; only API connects.
- **SSE routing must disable compression.** Set `X-Accel-Buffering: no` and use separate service/router.
- **CORS at both layers.** Edge (Traefik) and app (Spring) ensure compatibility.
- **Runtime env injection for frontend.** Never bake API URL into built image; use `docker-entrypoint.sh` + `window.__ENV`.
- **Idempotent queue submission.** API ensures same simulationId returns cached result (dedup by input hash).
